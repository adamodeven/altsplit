import Foundation
import SwiftData

/// Pure computations feeding the Progress tab. Kept free of SwiftUI/Charts
/// so the numbers behind every chart and list are independently testable.
enum ProgressCalculator {

    // MARK: - Body

    struct WeightPoint {
        let date: Date
        let pounds: Double
        let rollingAverage: Double
    }

    /// Trailing rolling average over `windowSize` check-ins (default 3),
    /// since a single weigh-in is noisy but the trend is the point.
    static func weightTrend(checkIns: [CheckIn], windowSize: Int = 3) -> [WeightPoint] {
        let sorted = checkIns.sorted { $0.date < $1.date }
        return sorted.enumerated().map { index, checkIn in
            let start = max(0, index - windowSize + 1)
            let window = sorted[start...index]
            let average = window.map(\.weightInPounds).reduce(0, +) / Double(window.count)
            return WeightPoint(date: checkIn.date, pounds: checkIn.weightInPounds, rollingAverage: average)
        }
    }

    struct CycleDelta: Identifiable {
        var id: Int { toCycle }
        let fromCycle: Int
        let toCycle: Int
        let deltaPounds: Double
    }

    static func cycleOverCycleDeltas(checkIns: [CheckIn]) -> [CycleDelta] {
        let sorted = checkIns.sorted { $0.cycleIndex < $1.cycleIndex }
        guard sorted.count > 1 else { return [] }
        return (1..<sorted.count).map { index in
            CycleDelta(
                fromCycle: sorted[index - 1].cycleIndex,
                toCycle: sorted[index].cycleIndex,
                deltaPounds: sorted[index].weightInPounds - sorted[index - 1].weightInPounds
            )
        }
    }

    // MARK: - Lifting

    struct OneRepMaxPoint {
        let date: Date
        let estimatedOneRepMax: Double
    }

    /// Best Epley estimate per session for one exercise, across time.
    static func oneRepMaxTrend(exercise: Exercise, sessions: [WorkoutSession]) -> [OneRepMaxPoint] {
        sessions.compactMap { session in
            let best = session.entries
                .filter { $0.exercise?.persistentModelID == exercise.persistentModelID && $0.isComplete }
                .compactMap(\.estimatedOneRepMax)
                .max()
            return best.map { OneRepMaxPoint(date: session.date, estimatedOneRepMax: $0) }
        }
        .sorted { $0.date < $1.date }
    }

    struct VolumeByCycle: Identifiable {
        var id: String { "\(cycleIndex)-\(muscleGroup.rawValue)" }
        let cycleIndex: Int
        let muscleGroup: MuscleGroup
        let volume: Double
    }

    static func volumeByCycle(sessions: [WorkoutSession], anchor: Date) -> [VolumeByCycle] {
        let calendar = PhaseCalculator.splitCalendar()
        var totals: [Int: [MuscleGroup: Double]] = [:]

        for session in sessions {
            let cycle = PhaseCalculator.cycleIndex(on: session.date, anchor: anchor, calendar: calendar)
            for entry in session.entries where entry.isComplete {
                guard let group = entry.exercise?.muscleGroup else { continue }
                totals[cycle, default: [:]][group, default: 0] += entry.volume
            }
        }

        return totals
            .flatMap { cycle, groups in groups.map { group, volume in VolumeByCycle(cycleIndex: cycle, muscleGroup: group, volume: volume) } }
            .sorted { ($0.cycleIndex, $0.muscleGroup.rawValue) < ($1.cycleIndex, $1.muscleGroup.rawValue) }
    }

    struct PersonalRecord: Identifiable {
        var id: String { "\(exerciseID)-\(date.timeIntervalSince1970)" }
        let exerciseID: PersistentIdentifier
        let exerciseName: String
        let date: Date
        let volume: Double
        let summary: String
    }

    /// Every set that beat its exercise's previous best volume, walking
    /// forward through time — cheap to compute, disproportionately
    /// motivating to see.
    static func personalRecords(sessions: [WorkoutSession]) -> [PersonalRecord] {
        var byExercise: [PersistentIdentifier: [(session: WorkoutSession, entry: SetEntry)]] = [:]
        for session in sessions {
            for entry in session.entries where entry.isComplete && entry.volume > 0 {
                guard let exercise = entry.exercise else { continue }
                byExercise[exercise.persistentModelID, default: []].append((session, entry))
            }
        }

        var records: [PersonalRecord] = []
        for pairs in byExercise.values {
            let chronological = pairs.sorted { $0.session.date < $1.session.date }
            var best = 0.0
            for pair in chronological where pair.entry.volume > best {
                best = pair.entry.volume
                guard let exercise = pair.entry.exercise else { continue }
                let summary = [pair.entry.weight.map { "\(Int($0))" }, pair.entry.reps.map { "\($0)" }]
                    .compactMap { $0 }
                    .joined(separator: " × ")
                records.append(PersonalRecord(
                    exerciseID: exercise.persistentModelID,
                    exerciseName: exercise.name,
                    date: pair.session.date,
                    volume: pair.entry.volume,
                    summary: summary
                ))
            }
        }
        return records.sorted { $0.date > $1.date }
    }

    struct PhaseComparison {
        let muscleGroup: MuscleGroup
        let phaseAAverageVolume: Double
        let phaseBAverageVolume: Double
    }

    /// Phase A vs. phase B average per-set volume for the same muscle
    /// group — the point of the split is that these differ meaningfully.
    static func phaseComparison(muscleGroup: MuscleGroup, sessions: [WorkoutSession]) -> PhaseComparison {
        var aTotal = 0.0, aCount = 0
        var bTotal = 0.0, bCount = 0

        for session in sessions {
            for entry in session.entries where entry.isComplete && entry.exercise?.muscleGroup == muscleGroup {
                if session.phase == .a {
                    aTotal += entry.volume
                    aCount += 1
                } else {
                    bTotal += entry.volume
                    bCount += 1
                }
            }
        }

        return PhaseComparison(
            muscleGroup: muscleGroup,
            phaseAAverageVolume: aCount > 0 ? aTotal / Double(aCount) : 0,
            phaseBAverageVolume: bCount > 0 ? bTotal / Double(bCount) : 0
        )
    }
}
