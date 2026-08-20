import Foundation

/// Which half of the two-week cycle a given week falls in.
enum Phase: String, Codable, CaseIterable, Sendable {
    case a
    case b

    var other: Phase { self == .a ? .b : .a }

    var displayName: String {
        switch self {
        case .a: "Week A"
        case .b: "Week B"
        }
    }

    var shortName: String {
        switch self {
        case .a: "A"
        case .b: "B"
        }
    }
}

/// Monday-first, matching the way the split is written.
enum Weekday: Int, Codable, CaseIterable, Sendable, Comparable {
    case monday = 1
    case tuesday, wednesday, thursday, friday, saturday, sunday

    /// Maps from `Calendar`'s Sunday-first `weekday` component.
    init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    var abbreviation: String { String(displayName.prefix(3)) }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// For AlarmKit's weekly recurrence, which speaks `Locale.Weekday`.
    var localeWeekday: Locale.Weekday {
        switch self {
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        case .sunday: .sunday
        }
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Sendable, Identifiable {
    case chest, back, shoulders, biceps, triceps, legs, core, forearms, glutes, calves

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .legs: "Legs"
        case .core: "Core"
        case .forearms: "Forearms"
        case .glutes: "Glutes"
        case .calves: "Calves"
        }
    }
}

/// Determines **what the logging UI shows**. Orthogonal to `Modality`.
enum ExerciseType: String, Codable, CaseIterable, Sendable {
    /// Weight × reps.
    case lift
    /// Duration under load — wall sits, planks, dead hangs.
    case hold
    /// Reps only, optionally with added weight.
    case bodyweight
    /// Distance, time, split per 500m, stroke rate.
    case erg
    /// Distance and time.
    case cardio

    var displayName: String {
        switch self {
        case .lift: "Lift"
        case .hold: "Hold"
        case .bodyweight: "Bodyweight"
        case .erg: "Erg"
        case .cardio: "Cardio"
        }
    }

    var tracksWeight: Bool { self == .lift || self == .bodyweight }
    var tracksReps: Bool { self == .lift || self == .bodyweight }
    var tracksDuration: Bool { self == .hold || self == .erg || self == .cardio }
    var tracksDistance: Bool { self == .erg || self == .cardio }
    var isStrength: Bool { self == .lift || self == .hold || self == .bodyweight }
}

/// Describes **the kind of stimulus**. Orthogonal to `ExerciseType`.
///
/// This is what makes phase A and phase B meaningfully different when they
/// target the same muscle group, and what makes training history queryable
/// by stimulus rather than just by movement.
enum Modality: String, Codable, CaseIterable, Sendable {
    case standard
    case plyometric
    case eccentric
    case isometric
    case tempo

    var displayName: String {
        switch self {
        case .standard: "Standard"
        case .plyometric: "Plyometric"
        case .eccentric: "Eccentric"
        case .isometric: "Isometric"
        case .tempo: "Tempo"
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Sendable {
    case barbell, dumbbell, cable, machine, bodyweight, kettlebell, band, ergometer, other

    var displayName: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .cable: "Cable"
        case .machine: "Machine"
        case .bodyweight: "Bodyweight"
        case .kettlebell: "Kettlebell"
        case .band: "Band"
        case .ergometer: "Erg"
        case .other: "Other"
        }
    }
}

/// What a given weekday is *for*, before phase resolution.
enum SlotKind: String, Codable, CaseIterable, Sendable {
    case lifting
    case cardio
    case rest
    /// Doubles up on `Program.currentFocus`, drawing from the opposite phase.
    case double

    var displayName: String {
        switch self {
        case .lifting: "Lifting"
        case .cardio: "Cardio"
        case .rest: "Rest"
        case .double: "Double"
        }
    }

    var isTrainingDay: Bool { self != .rest }

    /// Which `ExerciseType`s make sense to plan on a day of this kind. The
    /// workout tracker picks its top-level form (cardio vs. per-set rows)
    /// from the day's slot kind, so an erg exercise slotted into a lifting
    /// day renders no input fields at all rather than the cardio form.
    var allowedExerciseTypes: [ExerciseType] {
        switch self {
        case .lifting, .double: [.lift, .bodyweight, .hold]
        case .cardio: [.erg, .cardio]
        case .rest: ExerciseType.allCases
        }
    }
}

enum SessionStatus: String, Codable, CaseIterable, Sendable {
    case completed
    case partial
    case missed

    var displayName: String {
        switch self {
        case .completed: "Completed"
        case .partial: "Partial"
        case .missed: "Missed"
        }
    }

    /// Partial sessions count as half credit toward adherence.
    var adherenceCredit: Double {
        switch self {
        case .completed: 1.0
        case .partial: 0.5
        case .missed: 0.0
        }
    }
}
