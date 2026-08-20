import Foundation
import SwiftData

// MARK: - Units

extension UnitMass {
    /// Sensible display granularity per unit — converted values otherwise
    /// render as noise like "83.91 kg". Applied on both entry and display so
    /// stored values always trace back to a value that looked clean in
    /// whichever unit it was entered.
    var displayIncrement: Double {
        self == .kilograms ? 0.25 : 0.5
    }
}

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

    /// Derived from the muscle groups of whatever's actually in the pool, so
    /// the split editor never needs a separate manual picker that could
    /// drift from the exercises selected.
    ///
    /// `.double` days are the one exception: their pool is only a fallback
    /// used when nothing matches the dynamic `Program.currentFocus` (see
    /// `DayResolver.resolveDouble`), so deriving from it would hard-code
    /// whatever the fallback happens to train. Those keep the stored,
    /// manually-set value instead — empty means "use the dynamic focus."
    var groups: [MuscleGroup] {
        get {
            guard slotKind == .double else { return derivedGroups }
            return groupsRaw.compactMap(MuscleGroup.init(rawValue:))
        }
        set { groupsRaw = newValue.map(\.rawValue) }
    }

    private var derivedGroups: [MuscleGroup] {
        let present = Set((poolA + poolB).compactMap { $0.exercise?.muscleGroup })
        return MuscleGroup.allCases.filter(present.contains)
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
    var muscleGroupRaw: String?
    var equipmentRaw: String
    /// User-created exercises survive a library refresh.
    var isUserCreated: Bool
    var notes: String?

    var type: ExerciseType {
        get { ExerciseType(rawValue: typeRaw) ?? .lift }
        set { typeRaw = newValue.rawValue }
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
        muscleGroup: MuscleGroup? = nil,
        equipment: Equipment = .other,
        isUserCreated: Bool = false,
        notes: String? = nil
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.muscleGroupRaw = muscleGroup?.rawValue
        self.equipmentRaw = equipment.rawValue
        self.isUserCreated = isUserCreated
        self.notes = notes
    }
}

/// An exercise as scheduled within a day's pool, with its targets.
///
/// `modality` lives here rather than on `Exercise` because most movements can
/// be trained several ways (standard, tempo, eccentric, ...) and tagging the
/// exercise itself would force a separate library entry per variant. Picking
/// it per slot lets the same "Squat" appear twice in a pool — once standard,
/// once tempo — without duplicating the exercise.
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
    /// Defaulted so SwiftData can lightweight-migrate pool entries written
    /// before this column existed.
    var modalityRaw: String = "standard"

    var targetRepRange: ClosedRange<Int>? {
        guard let low = targetRepLow, let high = targetRepHigh, low <= high else { return nil }
        return low...high
    }

    var modality: Modality {
        get { Modality(rawValue: modalityRaw) ?? .standard }
        set { modalityRaw = newValue.rawValue }
    }

    init(
        exercise: Exercise?,
        order: Int,
        targetSets: Int = 3,
        targetRepRange: ClosedRange<Int>? = 8...12,
        targetDuration: TimeInterval? = nil,
        targetDistanceMeters: Int? = nil,
        restSeconds: Int = 90,
        notes: String? = nil,
        modality: Modality = .standard
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
        self.modalityRaw = modality.rawValue
    }

    /// Exercise name, with the modality appended when it's not standard —
    /// e.g. "Pull-Up · Eccentric" — so two slots for the same exercise read
    /// as distinct in a pool listing.
    var displayTitle: String {
        let name = exercise?.name ?? "—"
        return modality == .standard ? name : "\(name) · \(modality.displayName)"
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
    /// Display/entry unit for this session's sets. Weight is always stored
    /// canonically in kilograms on `SetEntry`; this only controls how it's
    /// typed and shown, and can change mid-session without touching history.
    var preferredUnitRaw: String = "lb"

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

    var preferredUnit: UnitMass {
        get { preferredUnitRaw == "kg" ? .kilograms : .pounds }
        set { preferredUnitRaw = newValue == .kilograms ? "kg" : "lb" }
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
        notes: String? = nil,
        preferredUnit: UnitMass = .pounds
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
        self.preferredUnitRaw = preferredUnit == .kilograms ? "kg" : "lb"
    }
}

@Model
final class SetEntry {
    var exercise: Exercise?
    var setIndex: Int
    /// Canonical storage, always kilograms — see `UnitMass.displayIncrement`
    /// and `WorkoutSession.preferredUnit`. Never mutated by a unit toggle, so
    /// flipping units mid-workout can't corrupt history and every chart stays
    /// comparable regardless of what was typed.
    var weightKilograms: Double?
    var reps: Int?
    var duration: TimeInterval?
    var rpe: Double?
    var isWarmup: Bool
    var completedAt: Date?
    /// Copied from the `PlannedExercise` it was logged against, so history
    /// and PR/1RM tracking can tell a tempo squat apart from a standard one
    /// even as the underlying `Exercise` stays the same. Defaulted so
    /// SwiftData can lightweight-migrate entries written before this column
    /// existed.
    var modalityRaw: String = "standard"

    var isComplete: Bool { completedAt != nil }

    var modality: Modality {
        get { Modality(rawValue: modalityRaw) ?? .standard }
        set { modalityRaw = newValue.rawValue }
    }

    init(
        exercise: Exercise?,
        setIndex: Int,
        weightKilograms: Double? = nil,
        reps: Int? = nil,
        duration: TimeInterval? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        completedAt: Date? = nil,
        modality: Modality = .standard
    ) {
        self.exercise = exercise
        self.setIndex = setIndex
        self.weightKilograms = weightKilograms
        self.reps = reps
        self.duration = duration
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.completedAt = completedAt
        self.modalityRaw = modality.rawValue
    }

    /// Reads back the weight in the given display unit, rounded to that
    /// unit's sensible increment (0.5 lb / 0.25 kg) so a value entered in one
    /// unit doesn't render as noise like "83.91 kg" in the other.
    func weight(in unit: UnitMass) -> Double? {
        guard let weightKilograms else { return nil }
        let value = Measurement(value: weightKilograms, unit: UnitMass.kilograms).converted(to: unit).value
        let increment = unit.displayIncrement
        return (value / increment).rounded() * increment
    }

    /// Sets the weight from a value typed in `unit`, rounding to that unit's
    /// increment before converting to the canonical kilogram store.
    func setWeight(_ displayValue: Double?, unit: UnitMass) {
        guard let displayValue else {
            weightKilograms = nil
            return
        }
        let increment = unit.displayIncrement
        let rounded = (displayValue / increment).rounded() * increment
        weightKilograms = Measurement(value: rounded, unit: unit).converted(to: .kilograms).value
    }

    /// Epley estimate. The cleanest single progress signal across varying rep
    /// schemes, which matters here because A and B weeks use different ones.
    var estimatedOneRepMax: Double? {
        guard let weightKilograms, let reps, weightKilograms > 0, reps > 0 else { return nil }
        guard reps > 1 else { return weightKilograms }
        return weightKilograms * (1.0 + Double(reps) / 30.0)
    }

    var volume: Double {
        guard let weightKilograms, let reps else { return 0 }
        return weightKilograms * Double(reps)
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
    /// Defaulted so SwiftData can lightweight-migrate existing on-disk logs
    /// (written before this column existed) without a custom migration plan.
    var multivitamin: Bool = false

    init(day: Date, protein: Bool = false, creatine: Bool = false, multivitamin: Bool = false) {
        self.day = day
        self.protein = protein
        self.creatine = creatine
        self.multivitamin = multivitamin
    }

    var allTaken: Bool { protein && creatine && multivitamin }
    var openCount: Int { (protein ? 0 : 1) + (creatine ? 0 : 1) + (multivitamin ? 0 : 1) }
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
