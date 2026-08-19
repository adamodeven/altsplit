import Testing
import Foundation
import SwiftData
@testable import AltSplit

@MainActor
struct ProgressCalculatorTests {

    func makeContext() throws -> ModelContext {
        let schema = Schema([
            Program.self, DayTemplate.self, Exercise.self, PlannedExercise.self,
            WorkoutSession.self, SetEntry.self, CardioResult.self,
            CheckIn.self, SupplementLog.self, SnoozeRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func date(_ daysFromEpoch: Int) -> Date {
        Date(timeIntervalSince1970: 0).addingTimeInterval(TimeInterval(daysFromEpoch * 86400))
    }

    // MARK: - Body

    @Test func weightTrendComputesTrailingRollingAverage() {
        let context = try! makeContext()
        let checkIns = [
            CheckIn(date: date(0), weightKilograms: 90, photoRef: "a", cycleIndex: 0),
            CheckIn(date: date(14), weightKilograms: 88, photoRef: "b", cycleIndex: 1),
            CheckIn(date: date(28), weightKilograms: 86, photoRef: "c", cycleIndex: 2),
        ]
        for c in checkIns { context.insert(c) }

        let points = ProgressCalculator.weightTrend(checkIns: checkIns, windowSize: 3)
        #expect(points.count == 3)
        // First point: window of just itself.
        #expect(abs(points[0].rollingAverage - points[0].pounds) < 0.001)
        // Third point: average of all three (window size 3, only 3 points exist).
        let expectedAvg = (points[0].pounds + points[1].pounds + points[2].pounds) / 3
        #expect(abs(points[2].rollingAverage - expectedAvg) < 0.001)
    }

    @Test func cycleOverCycleDeltasComputesConsecutiveDifferences() {
        let checkIns = [
            CheckIn(date: date(0), weightKilograms: 90, photoRef: "a", cycleIndex: 0),
            CheckIn(date: date(14), weightKilograms: 88, photoRef: "b", cycleIndex: 1),
            CheckIn(date: date(28), weightKilograms: 89, photoRef: "c", cycleIndex: 2),
        ]
        let deltas = ProgressCalculator.cycleOverCycleDeltas(checkIns: checkIns)
        #expect(deltas.count == 2)
        #expect(deltas[0].fromCycle == 0)
        #expect(deltas[0].toCycle == 1)
        #expect(deltas[0].deltaPounds < 0) // lost weight
        #expect(deltas[1].deltaPounds > 0) // gained back
    }

    @Test func cycleOverCycleDeltasIsEmptyForFewerThanTwoCheckIns() {
        let checkIns = [CheckIn(date: date(0), weightKilograms: 90, photoRef: "a", cycleIndex: 0)]
        #expect(ProgressCalculator.cycleOverCycleDeltas(checkIns: checkIns).isEmpty)
        #expect(ProgressCalculator.cycleOverCycleDeltas(checkIns: []).isEmpty)
    }

    // MARK: - Lifting

    @Test func oneRepMaxTrendTakesTheBestSetPerSession() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Bench", type: .lift, muscleGroup: .chest)
        context.insert(exercise)

        let session = WorkoutSession(date: date(0), phase: .a, weekday: .monday, status: .completed)
        context.insert(session)
        let weak = SetEntry(exercise: exercise, setIndex: 0, weightKilograms: 100, reps: 10, completedAt: date(0))
        let strong = SetEntry(exercise: exercise, setIndex: 1, weightKilograms: 150, reps: 5, completedAt: date(0))
        context.insert(weak)
        context.insert(strong)
        session.entries = [weak, strong]

        let trend = ProgressCalculator.oneRepMaxTrend(exercise: exercise, sessions: [session])
        #expect(trend.count == 1)
        #expect(trend[0].estimatedOneRepMax == strong.estimatedOneRepMax)
    }

    @Test func oneRepMaxTrendIgnoresIncompleteSets() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Bench", type: .lift, muscleGroup: .chest)
        context.insert(exercise)
        let session = WorkoutSession(date: date(0), phase: .a, weekday: .monday, status: .partial)
        context.insert(session)
        let incomplete = SetEntry(exercise: exercise, setIndex: 0, weightKilograms: 200, reps: 5, completedAt: nil)
        context.insert(incomplete)
        session.entries = [incomplete]

        #expect(ProgressCalculator.oneRepMaxTrend(exercise: exercise, sessions: [session]).isEmpty)
    }

    @Test func volumeByCycleGroupsByExerciseMuscleGroupAndCycle() throws {
        let context = try makeContext()
        let chest = Exercise(name: "Bench", type: .lift, muscleGroup: .chest)
        let back = Exercise(name: "Row", type: .lift, muscleGroup: .back)
        context.insert(chest)
        context.insert(back)

        let anchor = date(0)
        // Cycle 0: days 0-13. Cycle 1: days 14-27.
        let session0 = WorkoutSession(date: date(0), phase: .a, weekday: .monday, status: .completed)
        let session1 = WorkoutSession(date: date(14), phase: .a, weekday: .monday, status: .completed)
        context.insert(session0)
        context.insert(session1)

        let e1 = SetEntry(exercise: chest, setIndex: 0, weightKilograms: 100, reps: 10, completedAt: date(0)) // volume 1000
        let e2 = SetEntry(exercise: back, setIndex: 0, weightKilograms: 80, reps: 10, completedAt: date(0)) // volume 800
        let e3 = SetEntry(exercise: chest, setIndex: 0, weightKilograms: 110, reps: 10, completedAt: date(14)) // volume 1100
        context.insert(e1); context.insert(e2); context.insert(e3)
        session0.entries = [e1, e2]
        session1.entries = [e3]

        let result = ProgressCalculator.volumeByCycle(sessions: [session0, session1], anchor: anchor)
        let cycle0Chest = result.first { $0.cycleIndex == 0 && $0.muscleGroup == .chest }
        let cycle0Back = result.first { $0.cycleIndex == 0 && $0.muscleGroup == .back }
        let cycle1Chest = result.first { $0.cycleIndex == 1 && $0.muscleGroup == .chest }

        #expect(cycle0Chest?.volume == 1000)
        #expect(cycle0Back?.volume == 800)
        #expect(cycle1Chest?.volume == 1100)
    }

    @Test func personalRecordsOnlyFireWhenABestIsBeaten() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Squat", type: .lift, muscleGroup: .legs)
        context.insert(exercise)

        let s1 = WorkoutSession(date: date(0), phase: .a, weekday: .monday, status: .completed)
        let s2 = WorkoutSession(date: date(7), phase: .b, weekday: .monday, status: .completed)
        let s3 = WorkoutSession(date: date(14), phase: .a, weekday: .monday, status: .completed)
        context.insert(s1); context.insert(s2); context.insert(s3)

        let e1 = SetEntry(exercise: exercise, setIndex: 0, weightKilograms: 100, reps: 5, completedAt: date(0)) // vol 500 -> PR
        let e2 = SetEntry(exercise: exercise, setIndex: 0, weightKilograms: 90, reps: 5, completedAt: date(7)) // vol 450 -> not a PR
        let e3 = SetEntry(exercise: exercise, setIndex: 0, weightKilograms: 120, reps: 5, completedAt: date(14)) // vol 600 -> PR
        context.insert(e1); context.insert(e2); context.insert(e3)
        s1.entries = [e1]; s2.entries = [e2]; s3.entries = [e3]

        let records = ProgressCalculator.personalRecords(sessions: [s1, s2, s3])
        #expect(records.count == 2)
        // Sorted newest first.
        #expect(records[0].volume == 600)
        #expect(records[1].volume == 500)
    }

    @Test func phaseComparisonAveragesVolumePerPhase() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Overhead Press", type: .lift, muscleGroup: .shoulders)
        context.insert(exercise)

        let sessionA = WorkoutSession(date: date(0), phase: .a, weekday: .tuesday, status: .completed)
        let sessionB = WorkoutSession(date: date(7), phase: .b, weekday: .tuesday, status: .completed)
        context.insert(sessionA); context.insert(sessionB)

        let a1 = SetEntry(exercise: exercise, setIndex: 0, weightKilograms: 50, reps: 10, completedAt: date(0)) // 500
        let a2 = SetEntry(exercise: exercise, setIndex: 1, weightKilograms: 50, reps: 8, completedAt: date(0)) // 400
        let b1 = SetEntry(exercise: exercise, setIndex: 0, weightKilograms: 40, reps: 6, completedAt: date(7)) // 240
        context.insert(a1); context.insert(a2); context.insert(b1)
        sessionA.entries = [a1, a2]
        sessionB.entries = [b1]

        let comparison = ProgressCalculator.phaseComparison(muscleGroup: .shoulders, sessions: [sessionA, sessionB])
        #expect(comparison.phaseAAverageVolume == 450) // (500+400)/2
        #expect(comparison.phaseBAverageVolume == 240)
    }
}
