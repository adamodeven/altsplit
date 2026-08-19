import Foundation
import SwiftData

/// The default Mon–Sun split from DESIGN.md, with both phase pools
/// populated so the app is usable the moment it's first launched.
///
/// Phase B is never just phase A repeated: each day either targets a
/// different region of the same muscle (e.g. horizontal vs. vertical pull
/// on Monday) or the same movement with a different stimulus (eccentric,
/// plyometric, tempo).
enum DefaultProgram {
    static func seed(
        context: ModelContext,
        exercises: [String: Exercise],
        anchorDate: Date = PhaseCalculator.startOfWeek(for: .now)
    ) -> Program {
        func ex(_ name: String) -> Exercise {
            guard let exercise = exercises[name] else {
                fatalError("DefaultProgram references an exercise missing from the seeded library: \(name)")
            }
            return exercise
        }

        func reps(
            _ name: String, order: Int,
            sets: Int = 3, reps: ClosedRange<Int> = 8...12, rest: Int = 90,
            modality: Modality = .standard
        ) -> PlannedExercise {
            PlannedExercise(
                exercise: ex(name), order: order, targetSets: sets, targetRepRange: reps,
                restSeconds: rest, modality: modality
            )
        }

        func hold(
            _ name: String, order: Int,
            sets: Int = 3, duration: TimeInterval = 30, rest: Int = 60,
            modality: Modality = .standard
        ) -> PlannedExercise {
            PlannedExercise(
                exercise: ex(name), order: order, targetSets: sets,
                targetRepRange: nil, targetDuration: duration, restSeconds: rest, modality: modality
            )
        }

        func erg(_ name: String, order: Int, distanceMeters: Int) -> PlannedExercise {
            PlannedExercise(
                exercise: ex(name), order: order, targetSets: 1,
                targetRepRange: nil, targetDistanceMeters: distanceMeters, restSeconds: 0
            )
        }

        // MARK: Monday — biceps, back

        let monday = DayTemplate(
            weekday: .monday,
            groups: [.biceps, .back],
            slotKind: .lifting,
            poolA: [
                reps("Deadlift", order: 0, sets: 3, reps: 5...5, rest: 150),
                reps("Barbell Row", order: 1),
                reps("Barbell Curl", order: 2),
                reps("Hammer Curl", order: 3),
            ],
            poolB: [
                // Vertical pull instead of horizontal, and an eccentric
                // emphasis instead of straight sets — same groups, different
                // stimulus.
                reps("Pull-Up", order: 0, reps: 6...10),
                reps("Pull-Up", order: 1, sets: 3, reps: 4...6, rest: 120, modality: .eccentric),
                reps("Cable Curl", order: 2),
                reps("Dumbbell Curl", order: 3, reps: 6...8, modality: .eccentric),
            ]
        )

        // MARK: Tuesday — legs, shoulders

        let tuesday = DayTemplate(
            weekday: .tuesday,
            groups: [.legs, .shoulders],
            slotKind: .lifting,
            poolA: [
                reps("Back Squat", order: 0, sets: 4, reps: 5...8, rest: 150),
                reps("Romanian Deadlift", order: 1),
                reps("Overhead Press", order: 2),
                reps("Lateral Raise", order: 3, reps: 12...15, rest: 60),
            ],
            poolB: [
                // Front-loaded / unilateral legs, and an explosive press
                // instead of a strict one.
                reps("Front Squat", order: 0, sets: 4, reps: 5...8, rest: 150),
                reps("Bulgarian Split Squat", order: 1, reps: 8...10),
                reps("Push Press", order: 2, sets: 4, reps: 3...5, rest: 120, modality: .plyometric),
                reps("Arnold Press", order: 3),
            ]
        )

        // MARK: Wednesday — chest, triceps

        let wednesday = DayTemplate(
            weekday: .wednesday,
            groups: [.chest, .triceps],
            slotKind: .lifting,
            poolA: [
                reps("Barbell Bench Press", order: 0, sets: 4, reps: 5...8, rest: 150),
                reps("Incline Dumbbell Press", order: 1),
                reps("Close-Grip Bench Press", order: 2),
                reps("Tricep Pushdown", order: 3, reps: 12...15, rest: 60),
            ],
            poolB: [
                // Lower-chest region and a bodyweight/plyometric finisher.
                reps("Decline Barbell Press", order: 0, sets: 4, reps: 5...8, rest: 150),
                reps("Cable Fly", order: 1, reps: 12...15, rest: 60),
                reps("Skull Crusher", order: 2),
                reps("Diamond Push-Up", order: 3, reps: 10...15, rest: 60, modality: .plyometric),
            ]
        )

        // MARK: Thursday — rest

        let thursday = DayTemplate(weekday: .thursday, groups: [], slotKind: .rest)

        // MARK: Friday — erg

        let friday = DayTemplate(
            weekday: .friday,
            groups: [],
            slotKind: .cardio,
            poolA: [erg("5k Erg Steady State", order: 0, distanceMeters: 5000)],
            poolB: [erg("Erg Intervals", order: 0, distanceMeters: 4000)]
        )

        // MARK: Saturday — double (focused group, resolved dynamically)

        // Own fallback pool, used only when the current focus has no
        // matching weekday to borrow from (see DayResolver.resolveDouble).
        let saturday = DayTemplate(
            weekday: .saturday,
            groups: [],
            slotKind: .double,
            poolA: [
                hold("Plank", order: 0, duration: 45),
                reps("Hanging Leg Raise", order: 1, reps: 10...15, rest: 60),
            ],
            poolB: [
                hold("Side Plank", order: 0, duration: 30),
                reps("Ab Wheel Rollout", order: 1, sets: 3, reps: 8...12, rest: 60),
            ]
        )

        // MARK: Sunday — rest

        let sunday = DayTemplate(weekday: .sunday, groups: [], slotKind: .rest)

        let days = [monday, tuesday, wednesday, thursday, friday, saturday, sunday]
        for day in days {
            context.insert(day)
        }

        let program = Program(
            anchorDate: anchorDate,
            currentFocus: .shoulders,
            focusConfirmedAt: .now,
            checkInIntervalDays: 14,
            days: days
        )
        context.insert(program)
        return program
    }
}
