import Foundation
import SwiftData

// MARK: - Program

/// Singleton-ish root object. Exactly one is expected to exist.
@Model
final class Program {
    /// Anchors the A/B alternation. Phase is derived from calendar distance
    /// to this date, never from completion, so a missed week logs as missed
    /// rather than shifting the schedule.
    var anchorDate: Date

    /// Muscle group the Saturday double currently targets.
    var currentFocusRaw: String

    /// When the focus was last confirmed, so it can be re-prompted before it
    /// goes stale.
    var focusConfirmedAt: Date

    /// Days between weight/photo check-ins. 14 keeps them aligned to the
    /// start of each A-week.
    var checkInIntervalDays: Int

    @Relationship(deleteRule: .cascade)
    var days: [DayTemplate]

    var currentFocus: MuscleGroup {
        get { MuscleGroup(rawValue: currentFocusRaw) ?? .shoulders }
        set { currentFocusRaw = newValue.rawValue }
    }

    init(
        anchorDate: Date = .now,
        currentFocus: MuscleGroup = .shoulders,
        focusConfirmedAt: Date = .now,
        checkInIntervalDays: Int = 14,
        days: [DayTemplate] = []
    ) {
        self.anchorDate = anchorDate
        self.currentFocusRaw = currentFocus.rawValue
        self.focusConfirmedAt = focusConfirmedAt
        self.checkInIntervalDays = checkInIntervalDays
        self.days = days
    }

    func day(for weekday: Weekday) -> DayTemplate? {
        days.first { $0.weekday == weekday }
    }
}

// MARK: - Week shape

/// One weekday of the shared weekly skeleton.
///
/// The skeleton is defined once; phase A and phase B differ only in which
/// exercise pool is drawn from.
@Model
final class DayTemplate {
    var weekdayRaw: Int
    var groupsRaw: [String]
    var slotKindRaw: String

    @Relationship(deleteRule: .cascade)
    var poolA: [PlannedExercise]

    @Relationship(deleteRule: .cascade)
    var poolB: [PlannedExercise]

    var weekday: Weekday {
        get { Weekday(rawValue: weekdayRaw) ?? .monday }
        set { weekdayRaw = newValue.rawValue }
    }

    var groups: [MuscleGroup] {
        get { groupsRaw.compactMap(MuscleGroup.init(rawValue:)) }
        set { groupsRaw = newValue.map(\.rawValue) }
    }

    var slotKind: SlotKind {
        get { SlotKind(rawValue: slotKindRaw) ?? .rest }
        set { slotKindRaw = newValue.rawValue }
    }

    init(
        weekday: Weekday,
        groups: [MuscleGroup] = [],
        slotKind: SlotKind = .rest,
        poolA: [PlannedExercise] = [],
        poolB: [PlannedExercise] = []
    ) {
        self.weekdayRaw = weekday.rawValue
        self.groupsRaw = groups.map(\.rawValue)
        self.slotKindRaw = slotKind.rawValue
        self.poolA = poolA
        self.poolB = poolB
    }

    func pool(for phase: Phase) -> [PlannedExercise] {
        (phase == .a ? poolA : poolB).sorted { $0.order < $1.order }
    }

    var title: String {
        switch slotKind {
        case .rest: "Rest"
        case .double: "Double"
        case .cardio where groups.isEmpty: "Erg"
        default:
            groups.isEmpty
                ? slotKind.displayName
                : groups.map(\.displayName).joined(separator: " + ")
        }
    }
}

// MARK: - Exercise library

@Model
final class Exercise {
    #Unique<Exercise>([\.name])

    var name: String
    var typeRaw: String
    var modalityRaw: String
    var muscleGroupRaw: String?
    var equipmentRaw: String
    /// User-created exercises survive a library refresh.
    var isUserCreated: Bool
    var notes: String?

    var type: ExerciseType {
        get { ExerciseType(rawValue: typeRaw) ?? .lift }
        set { typeRaw = newValue.rawValue }
    }

    var modality: Modality {
        get { Modality(rawValue: modalityRaw) ?? .standard }
        set { modalityRaw = newValue.rawValue }
    }

    var muscleGroup: MuscleGroup? {
        get { muscleGroupRaw.flatMap(MuscleGroup.init(rawValue:)) }
        set { muscleGroupRaw = newValue?.rawValue }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }

    init(
        name: String,
        type: ExerciseType,
        modality: Modality = .standard,
        muscleGroup: MuscleGroup? = nil,
        equipment: Equipment = .other,
        isUserCreated: Bool = false,
        notes: String? = nil
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.modalityRaw = modality.rawValue
        self.muscleGroupRaw = muscleGroup?.rawValue
        self.equipmentRaw = equipment.rawValue
        self.isUserCreated = isUserCreated
        self.notes = notes
    }
}

/// An exercise as scheduled within a day's pool, with its targets.
@Model
final class PlannedExercise {
    var exercise: Exercise?
    var order: Int
    var targetSets: Int
    var targetRepLow: Int?
    var targetRepHigh: Int?
    var targetDuration: TimeInterval?
    var targetDistanceMeters: Int?
    var restSeconds: Int
    var notes: String?

    var targetRepRange: ClosedRange<Int>? {
        guard let low = targetRepLow, let high = targetRepHigh, low <= high else { return nil }
        return low...high
    }

    init(
        exercise: Exercise?,
        order: Int,
        targetSets: Int = 3,
        targetRepRange: ClosedRange<Int>? = 8...12,
        targetDuration: TimeInterval? = nil,
        targetDistanceMeters: Int? = nil,
        restSeconds: Int = 90,
        notes: String? = nil
    ) {
        self.exercise = exercise
        self.order = order
        self.targetSets = targetSets
        self.targetRepLow = targetRepRange?.lowerBound
        self.targetRepHigh = targetRepRange?.upperBound
        self.targetDuration = targetDuration
        self.targetDistanceMeters = targetDistanceMeters
        self.restSeconds = restSeconds
        self.notes = notes
    }

    var targetSummary: String {
        guard let exercise else { return "\(targetSets) sets" }
        switch exercise.type {
        case .lift, .bodyweight:
            if let range = targetRepRange {
                return range.lowerBound == range.upperBound
                    ? "\(targetSets) × \(range.lowerBound)"
                    : "\(targetSets) × \(range.lowerBound)–\(range.upperBound)"
            }
            return "\(targetSets) sets"
        case .hold:
            let seconds = Int(targetDuration ?? 30)
            return "\(targetSets) × \(seconds)s"
        case .erg, .cardio:
            if let meters = targetDistanceMeters {
                return meters >= 1000
                    ? "\(meters / 1000)k"
                    : "\(meters)m"
            }
            if let duration = targetDuration {
                return "\(Int(duration / 60)) min"
            }
            return "—"
        }
    }
}

// MARK: - Logged work

@Model
final class WorkoutSession {
    var date: Date
    var phaseRaw: String
    var statusRaw: String
    var weekdayRaw: Int
    /// Set when the day resolved as a double, recording which group was hit.
    var focusGroupRaw: String?
    var startedAt: Date?
    var endedAt: Date?
    var notes: String?

    @Relationship(deleteRule: .cascade)
    var entries: [SetEntry]

    @Relationship(deleteRule: .cascade)
    var cardioResult: CardioResult?

    var phase: Phase {
        get { Phase(rawValue: phaseRaw) ?? .a }
        set { phaseRaw = newValue.rawValue }
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .partial }
        set { statusRaw = newValue.rawValue }
    }

    var weekday: Weekday {
        get { Weekday(rawValue: weekdayRaw) ?? .monday }
        set { weekdayRaw = newValue.rawValue }
    }

    var focusGroup: MuscleGroup? {
        get { focusGroupRaw.flatMap(MuscleGroup.init(rawValue:)) }
        set { focusGroupRaw = newValue?.rawValue }
    }

    var duration: TimeInterval? {
        guard let startedAt, let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    init(
        date: Date,
        phase: Phase,
        weekday: Weekday,
        status: SessionStatus = .partial,
        focusGroup: MuscleGroup? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        entries: [SetEntry] = [],
        cardioResult: CardioResult? = nil,
        notes: String? = nil
    ) {
        self.date = date
        self.phaseRaw = phase.rawValue
        self.weekdayRaw = weekday.rawValue
        self.statusRaw = status.rawValue
        self.focusGroupRaw = focusGroup?.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entries = entries
        self.cardioResult = cardioResult
        self.notes = notes
    }
}

@Model
final class SetEntry {
    var exercise: Exercise?
    var setIndex: Int
    var weight: Double?
    var reps: Int?
    var duration: TimeInterval?
    var rpe: Double?
    var isWarmup: Bool
    var completedAt: Date?

    var isComplete: Bool { completedAt != nil }

    init(
        exercise: Exercise?,
        setIndex: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        duration: TimeInterval? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        completedAt: Date? = nil
    ) {
        self.exercise = exercise
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.completedAt = completedAt
    }

    /// Epley estimate. The cleanest single progress signal across varying rep
    /// schemes, which matters here because A and B weeks use different ones.
    var estimatedOneRepMax: Double? {
        guard let weight, let reps, weight > 0, reps > 0 else { return nil }
        guard reps > 1 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    var volume: Double {
        guard let weight, let reps else { return 0 }
        return weight * Double(reps)
    }
}

@Model
final class CardioResult {
    var distanceMeters: Int
    var duration: TimeInterval
    var avgStrokeRate: Int?
    var avgHeartRate: Int?

    init(
        distanceMeters: Int,
        duration: TimeInterval,
        avgStrokeRate: Int? = nil,
        avgHeartRate: Int? = nil
    ) {
        self.distanceMeters = distanceMeters
        self.duration = duration
        self.avgStrokeRate = avgStrokeRate
        self.avgHeartRate = avgHeartRate
    }

    /// Seconds per 500m — the standard erg pace unit.
    var avgSplit: TimeInterval? {
        guard distanceMeters > 0 else { return nil }
        return duration / (Double(distanceMeters) / 500.0)
    }

    var formattedSplit: String {
        guard let avgSplit else { return "—" }
        let minutes = Int(avgSplit) / 60
        let seconds = avgSplit - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, seconds)
    }
}

// MARK: - Check-ins

/// Weight and photo, atomically. There is deliberately no initialiser that
/// permits one without the other — a check-in with a weight but no photo is
/// not a check-in.
@Model
final class CheckIn {
    var date: Date
    var weightKilograms: Double
    /// Filename within the app's protected container. Never the camera roll.
    var photoRef: String
    var cycleIndex: Int
    var notes: String?

    init(
        date: Date,
        weightKilograms: Double,
        photoRef: String,
        cycleIndex: Int,
        notes: String? = nil
    ) {
        self.date = date
        self.weightKilograms = weightKilograms
        self.photoRef = photoRef
        self.cycleIndex = cycleIndex
        self.notes = notes
    }

    var weight: Measurement<UnitMass> {
        Measurement(value: weightKilograms, unit: .kilograms)
    }

    var weightInPounds: Double {
        weight.converted(to: .pounds).value
    }
}

@Model
final class SupplementLog {
    #Unique<SupplementLog>([\.day])

    /// Start of day, so there is exactly one log per calendar day.
    var day: Date
    var protein: Bool
    var creatine: Bool

    init(day: Date, protein: Bool = false, creatine: Bool = false) {
        self.day = day
        self.protein = protein
        self.creatine = creatine
    }

    var allTaken: Bool { protein && creatine }
    var openCount: Int { (protein ? 0 : 1) + (creatine ? 0 : 1) }
}

/// Records a deferred reminder so snoozing is visible rather than free.
@Model
final class SnoozeRecord {
    var date: Date
    var kindRaw: String

    init(date: Date = .now, kind: String) {
        self.date = date
        self.kindRaw = kind
    }
}
