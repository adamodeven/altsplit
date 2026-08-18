import Testing
import Foundation
import SwiftData
@testable import AltSplit

@MainActor
struct DayResolverTests {

    // MARK: - Fixture

    /// Builds a minimal but realistic program: Monday (biceps/back),
    /// Tuesday (legs/shoulders), Saturday (double), all backed by an
    /// in-memory SwiftData context so relationships behave as they would in
    /// the real app.
    struct Fixture {
        let context: ModelContext
        let program: Program
        let calendar: Calendar

        let tuesdayShoulderA: Exercise
        let tuesdayShoulderB: Exercise
        let tuesdayLegA: Exercise
        let tuesdayLegB: Exercise
        let saturdayOwnExercise: Exercise

        /// Saturday of the program's own anchor week (always phase A) or the
        /// following week (always phase B).
        func saturday(phase: Phase) -> Date {
            let anchorWeekStart = PhaseCalculator.startOfWeek(for: program.anchorDate, calendar: calendar)
            let dayOffset = phase == .a ? 5 : 12
            return calendar.date(byAdding: .day, value: dayOffset, to: anchorWeekStart)!
        }
    }

    func makeFixture(currentFocus: MuscleGroup = .shoulders) throws -> Fixture {
        let schema = Schema([
            Program.self, DayTemplate.self, Exercise.self, PlannedExercise.self,
            WorkoutSession.self, SetEntry.self, CardioResult.self,
            CheckIn.self, SupplementLog.self, SnoozeRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        func exercise(_ name: String, _ group: MuscleGroup) -> Exercise {
            let ex = Exercise(name: name, type: .lift, modality: .standard, muscleGroup: group)
            context.insert(ex)
            return ex
        }

        let tuesdayShoulderA = exercise("Overhead Press", .shoulders)
        let tuesdayShoulderB = exercise("Arnold Press", .shoulders)
        let tuesdayLegA = exercise("Back Squat", .legs)
        let tuesdayLegB = exercise("Front Squat", .legs)
        let saturdayOwnExercise = exercise("Plank", .core)

        let tuesday = DayTemplate(
            weekday: .tuesday,
            groups: [.legs, .shoulders],
            slotKind: .lifting,
            poolA: [
                PlannedExercise(exercise: tuesdayLegA, order: 0),
                PlannedExercise(exercise: tuesdayShoulderA, order: 1),
            ],
            poolB: [
                PlannedExercise(exercise: tuesdayLegB, order: 0),
                PlannedExercise(exercise: tuesdayShoulderB, order: 1),
            ]
        )

        let saturday = DayTemplate(
            weekday: .saturday,
            groups: [],
            slotKind: .double,
            poolA: [PlannedExercise(exercise: saturdayOwnExercise, order: 0)],
            poolB: [PlannedExercise(exercise: saturdayOwnExercise, order: 0)]
        )

        let monday = DayTemplate(weekday: .monday, groups: [.biceps, .back], slotKind: .lifting)
        let sunday = DayTemplate(weekday: .sunday, groups: [], slotKind: .rest)

        for day in [monday, tuesday, saturday, sunday] {
            context.insert(day)
        }

        // Anchor at a known Monday so `saturday(phase:)` above is exact.
        let calendar = PhaseCalculator.splitCalendar()
        let anchorDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))! // Monday

        let program = Program(
            anchorDate: anchorDate,
            currentFocus: currentFocus,
            days: [monday, tuesday, saturday, sunday]
        )
        context.insert(program)

        return Fixture(
            context: context,
            program: program,
            calendar: calendar,
            tuesdayShoulderA: tuesdayShoulderA,
            tuesdayShoulderB: tuesdayShoulderB,
            tuesdayLegA: tuesdayLegA,
            tuesdayLegB: tuesdayLegB,
            saturdayOwnExercise: saturdayOwnExercise
        )
    }

    // MARK: - Double day pulls the OPPOSITE phase's pool for the focus group

    @Test func doubleDayOnPhaseAPullsPhaseBExercisesForFocusGroup() throws {
        let fixture = try makeFixture(currentFocus: .shoulders)
        let resolver = DayResolver(program: fixture.program, calendar: fixture.calendar)

        let resolved = resolver.resolve(for: fixture.saturday(phase: .a))

        #expect(resolved.phase == .a)
        #expect(resolved.isDouble)
        #expect(resolved.focusGroup == .shoulders)
        #expect(resolved.sourcePhase == .b) // opposite of .a
        #expect(resolved.exercises.count == 1)
        #expect(resolved.exercises.first?.exercise === fixture.tuesdayShoulderB)
        // Must not include the leg work from the same day/pool.
        #expect(!resolved.exercises.contains { $0.exercise === fixture.tuesdayLegB })
    }

    @Test func doubleDayOnPhaseBPullsPhaseAExercisesForFocusGroup() throws {
        let fixture = try makeFixture(currentFocus: .shoulders)
        let resolver = DayResolver(program: fixture.program, calendar: fixture.calendar)

        let resolved = resolver.resolve(for: fixture.saturday(phase: .b))

        #expect(resolved.phase == .b)
        #expect(resolved.sourcePhase == .a) // opposite of .b
        #expect(resolved.exercises.count == 1)
        #expect(resolved.exercises.first?.exercise === fixture.tuesdayShoulderA)
    }

    @Test func doubleDayGroupsReflectOnlyTheFocusOnSuccess() throws {
        let fixture = try makeFixture(currentFocus: .shoulders)
        let resolver = DayResolver(program: fixture.program, calendar: fixture.calendar)

        let resolved = resolver.resolve(for: fixture.saturday(phase: .a))
        #expect(resolved.groups == [.shoulders])
    }

    // MARK: - Fallback to the day's own pool when nothing matches

    @Test func doubleDayFallsBackToOwnPoolWhenFocusHasNoSourceDay() throws {
        // No day in the program trains .calves, so there is no source day to
        // borrow from at all.
        let fixture = try makeFixture(currentFocus: .calves)
        let resolver = DayResolver(program: fixture.program, calendar: fixture.calendar)

        let resolved = resolver.resolve(for: fixture.saturday(phase: .a))

        #expect(resolved.isDouble)
        #expect(resolved.focusGroup == .calves)
        // Fallback keeps the day's *own* phase, not the opposite one.
        #expect(resolved.sourcePhase == .a)
        #expect(resolved.exercises.count == 1)
        #expect(resolved.exercises.first?.exercise === fixture.saturdayOwnExercise)
    }

    @Test func doubleDayFallsBackWhenSourceDayExistsButOppositePoolHasNoMatch() throws {
        // Focus on .legs: Tuesday trains legs, but rig the fixture so the
        // *opposite* phase's pool for Tuesday has no leg exercise — only
        // shoulder work — forcing an empty `borrowed` result.
        let schema = Schema([
            Program.self, DayTemplate.self, Exercise.self, PlannedExercise.self,
            WorkoutSession.self, SetEntry.self, CardioResult.self,
            CheckIn.self, SupplementLog.self, SnoozeRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let shoulderOnly = Exercise(name: "Lateral Raise", type: .lift, muscleGroup: .shoulders)
        let ownPool = Exercise(name: "Wall Sit", type: .hold, muscleGroup: .legs)
        context.insert(shoulderOnly)
        context.insert(ownPool)

        let tuesday = DayTemplate(
            weekday: .tuesday,
            groups: [.legs, .shoulders],
            slotKind: .lifting,
            poolA: [PlannedExercise(exercise: shoulderOnly, order: 0)], // no leg exercise here
            poolB: [PlannedExercise(exercise: shoulderOnly, order: 0)]
        )
        let saturday = DayTemplate(
            weekday: .saturday,
            groups: [],
            slotKind: .double,
            poolA: [PlannedExercise(exercise: ownPool, order: 0)],
            poolB: [PlannedExercise(exercise: ownPool, order: 0)]
        )
        context.insert(tuesday)
        context.insert(saturday)

        let calendar = PhaseCalculator.splitCalendar()
        let anchorDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))! // Monday

        let program = Program(
            anchorDate: anchorDate,
            currentFocus: .legs,
            days: [tuesday, saturday]
        )
        context.insert(program)

        let resolver = DayResolver(program: program, calendar: calendar)
        let saturdayPhaseA = calendar.date(byAdding: .day, value: 5, to: anchorDate)!
        let resolved = resolver.resolve(for: saturdayPhaseA)

        #expect(resolved.sourcePhase == .a) // fell back to own phase
        #expect(resolved.exercises.count == 1)
        #expect(resolved.exercises.first?.exercise === ownPool)
    }

    @Test func doubleDayFallbackUsesTemplateGroupsWhenPresent() throws {
        let fixture = try makeFixture(currentFocus: .calves)
        let saturdayTemplate = fixture.program.day(for: .saturday)!
        saturdayTemplate.groups = [.core] // day explicitly declares its own groups

        let resolver = DayResolver(program: fixture.program, calendar: fixture.calendar)
        let resolved = resolver.resolve(for: fixture.saturday(phase: .a))

        // Falls back to the day's own declared groups rather than [.calves]
        // when the template specifies them.
        #expect(resolved.groups == [.core])
        #expect(resolved.focusGroup == .calves)
    }

    // MARK: - Non-double days are unaffected

    @Test func nonDoubleDayResolvesNormallyForTheGivenPhase() throws {
        let fixture = try makeFixture(currentFocus: .shoulders)
        let resolver = DayResolver(program: fixture.program, calendar: fixture.calendar)

        let tuesdayA = fixture.calendar.date(byAdding: .day, value: 1, to: fixture.program.anchorDate)!
        let resolved = resolver.resolve(for: tuesdayA)

        #expect(resolved.slotKind == .lifting)
        #expect(resolved.focusGroup == nil)
        #expect(resolved.sourcePhase == .a)
        #expect(resolved.exercises.map { $0.exercise } == [fixture.tuesdayLegA, fixture.tuesdayShoulderA])
    }
}
