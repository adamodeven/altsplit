import Foundation
import SwiftData

/// The default exercise library, seeded once on first launch.
///
/// `type` drives the logging UI; `modality` is an orthogonal descriptive tag
/// used to differentiate phase A from phase B on the same muscle group. Every
/// entry here is `isUserCreated == false` so a future library refresh can
/// safely leave user-created exercises alone.
enum ExerciseLibrary {
    struct Spec {
        let name: String
        let type: ExerciseType
        let muscleGroup: MuscleGroup?
        let equipment: Equipment
        let modality: Modality

        /// `modality` trails with a default so most call sites — which are
        /// all `.standard` — can omit it positionally.
        init(
            _ name: String,
            _ type: ExerciseType,
            _ muscleGroup: MuscleGroup?,
            _ equipment: Equipment,
            _ modality: Modality = .standard
        ) {
            self.name = name
            self.type = type
            self.muscleGroup = muscleGroup
            self.equipment = equipment
            self.modality = modality
        }
    }

    static let all: [Spec] = chest + back + shoulders + biceps + triceps
        + legs + core + forearms + glutes + calves + erg

    static let chest: [Spec] = [
        Spec("Barbell Bench Press", .lift, .chest, .barbell),
        Spec("Incline Dumbbell Press", .lift, .chest, .dumbbell),
        Spec("Decline Barbell Press", .lift, .chest, .barbell),
        Spec("Cable Fly", .lift, .chest, .cable),
        Spec("Dumbbell Pullover", .lift, .chest, .dumbbell),
        Spec("Push-Up", .bodyweight, .chest, .bodyweight),
        Spec("Plyometric Push-Up", .bodyweight, .chest, .bodyweight, .plyometric),
        Spec("Tempo Bench Press", .lift, .chest, .barbell, .tempo),
    ]

    static let back: [Spec] = [
        Spec("Deadlift", .lift, .back, .barbell),
        Spec("Pull-Up", .bodyweight, .back, .bodyweight),
        Spec("Barbell Row", .lift, .back, .barbell),
        Spec("Lat Pulldown", .lift, .back, .cable),
        Spec("Seated Cable Row", .lift, .back, .cable),
        Spec("Single-Arm Dumbbell Row", .lift, .back, .dumbbell),
        Spec("T-Bar Row", .lift, .back, .machine),
        Spec("Eccentric Pull-Up", .bodyweight, .back, .bodyweight, .eccentric),
    ]

    static let shoulders: [Spec] = [
        Spec("Overhead Press", .lift, .shoulders, .barbell),
        Spec("Arnold Press", .lift, .shoulders, .dumbbell),
        Spec("Lateral Raise", .lift, .shoulders, .dumbbell),
        Spec("Cable Lateral Raise", .lift, .shoulders, .cable),
        Spec("Front Raise", .lift, .shoulders, .dumbbell),
        Spec("Face Pull", .lift, .shoulders, .cable),
        Spec("Push Press", .lift, .shoulders, .barbell, .plyometric),
        Spec("Handstand Hold", .hold, .shoulders, .bodyweight, .isometric),
    ]

    static let biceps: [Spec] = [
        Spec("Barbell Curl", .lift, .biceps, .barbell),
        Spec("Dumbbell Curl", .lift, .biceps, .dumbbell),
        Spec("Hammer Curl", .lift, .biceps, .dumbbell),
        Spec("Cable Curl", .lift, .biceps, .cable),
        Spec("Preacher Curl", .lift, .biceps, .machine),
        Spec("Chin-Up", .bodyweight, .biceps, .bodyweight),
        Spec("Eccentric Dumbbell Curl", .lift, .biceps, .dumbbell, .eccentric),
    ]

    static let triceps: [Spec] = [
        Spec("Close-Grip Bench Press", .lift, .triceps, .barbell),
        Spec("Tricep Pushdown", .lift, .triceps, .cable),
        Spec("Overhead Tricep Extension", .lift, .triceps, .dumbbell),
        Spec("Skull Crusher", .lift, .triceps, .barbell),
        Spec("Dip", .bodyweight, .triceps, .bodyweight),
        Spec("Diamond Push-Up", .bodyweight, .triceps, .bodyweight),
        Spec("Plyo Dip", .bodyweight, .triceps, .bodyweight, .plyometric),
    ]

    static let legs: [Spec] = [
        Spec("Back Squat", .lift, .legs, .barbell),
        Spec("Front Squat", .lift, .legs, .barbell),
        Spec("Romanian Deadlift", .lift, .legs, .barbell),
        Spec("Leg Press", .lift, .legs, .machine),
        Spec("Walking Lunge", .lift, .legs, .dumbbell),
        Spec("Bulgarian Split Squat", .lift, .legs, .dumbbell),
        Spec("Leg Extension", .lift, .legs, .machine),
        Spec("Leg Curl", .lift, .legs, .machine),
        Spec("Tempo Squat", .lift, .legs, .barbell, .tempo),
        Spec("Box Jump", .bodyweight, .legs, .bodyweight, .plyometric),
        Spec("Wall Sit", .hold, .legs, .bodyweight, .isometric),
    ]

    static let core: [Spec] = [
        Spec("Plank", .hold, .core, .bodyweight, .isometric),
        Spec("Side Plank", .hold, .core, .bodyweight, .isometric),
        Spec("Hanging Leg Raise", .bodyweight, .core, .bodyweight),
        Spec("Cable Crunch", .lift, .core, .cable),
        Spec("Russian Twist", .bodyweight, .core, .bodyweight),
        Spec("Ab Wheel Rollout", .bodyweight, .core, .bodyweight),
    ]

    static let forearms: [Spec] = [
        Spec("Wrist Curl", .lift, .forearms, .dumbbell),
        Spec("Reverse Curl", .lift, .forearms, .barbell),
        Spec("Dead Hang", .hold, .forearms, .bodyweight, .isometric),
        Spec("Farmer's Carry", .hold, .forearms, .dumbbell),
    ]

    static let glutes: [Spec] = [
        Spec("Hip Thrust", .lift, .glutes, .barbell),
        Spec("Sumo Deadlift", .lift, .glutes, .barbell),
        Spec("Cable Kickback", .lift, .glutes, .cable),
        Spec("Glute Bridge", .bodyweight, .glutes, .bodyweight),
        Spec("Single-Leg Glute Bridge", .bodyweight, .glutes, .bodyweight),
    ]

    static let calves: [Spec] = [
        Spec("Standing Calf Raise", .lift, .calves, .machine),
        Spec("Seated Calf Raise", .lift, .calves, .machine),
        Spec("Single-Leg Calf Raise", .bodyweight, .calves, .bodyweight),
        Spec("Calf Raise Hold", .hold, .calves, .bodyweight, .isometric),
    ]

    static let erg: [Spec] = [
        Spec("500m Erg Sprint", .erg, nil, .ergometer),
        Spec("1k Erg", .erg, nil, .ergometer),
        Spec("2k Erg Test", .erg, nil, .ergometer),
        Spec("5k Erg Steady State", .erg, nil, .ergometer),
        Spec("10k Erg Steady State", .erg, nil, .ergometer),
        Spec("Erg Intervals", .erg, nil, .ergometer),
    ]

    /// Inserts the full library into `context` and returns a name → Exercise
    /// lookup for wiring up the default program's day pools.
    @discardableResult
    static func seed(into context: ModelContext) -> [String: Exercise] {
        var lookup: [String: Exercise] = [:]
        for spec in all {
            let exercise = Exercise(
                name: spec.name,
                type: spec.type,
                modality: spec.modality,
                muscleGroup: spec.muscleGroup,
                equipment: spec.equipment,
                isUserCreated: false
            )
            context.insert(exercise)
            lookup[spec.name] = exercise
        }
        return lookup
    }
}
