import Testing
import Foundation
import SwiftData
@testable import AltSplit

@MainActor
struct DefaultProgramTests {

    func makeProgram() throws -> (Program, ModelContext) {
        let schema = Schema([
            Program.self, DayTemplate.self, Exercise.self, PlannedExercise.self,
            WorkoutSession.self, SetEntry.self, CardioResult.self,
            CheckIn.self, SupplementLog.self, SnoozeRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let exercises = ExerciseLibrary.seed(into: context)
        let anchor = PhaseCalculator.splitCalendar()
            .date(from: DateComponents(year: 2026, month: 1, day: 5))! // Monday
        let program = DefaultProgram.seed(context: context, exercises: exercises, anchorDate: anchor)
        try context.save()
        return (program, context)
    }

    @Test func seedsAllSevenWeekdays() throws {
        let (program, _) = try makeProgram()
        #expect(Set(program.days.map(\.weekday)) == Set(Weekday.allCases))
    }

    @Test func weekShapeMatchesDesign() throws {
        let (program, _) = try makeProgram()

        let expected: [Weekday: (SlotKind, Set<MuscleGroup>)] = [
            .monday: (.lifting, [.biceps, .back]),
            .tuesday: (.lifting, [.legs, .shoulders]),
            .wednesday: (.lifting, [.chest, .triceps]),
            .thursday: (.rest, []),
            .friday: (.cardio, []),
            .saturday: (.double, []),
            .sunday: (.rest, []),
        ]

        for (weekday, (slotKind, groups)) in expected {
            let day = program.day(for: weekday)
            #expect(day?.slotKind == slotKind, "\(weekday) slotKind")
            #expect(Set(day?.groups ?? []) == groups, "\(weekday) groups")
        }
    }

    @Test func trainingDaysHavePopulatedPoolsForBothPhases() throws {
        let (program, _) = try makeProgram()
        for weekday: Weekday in [.monday, .tuesday, .wednesday, .friday, .saturday] {
            let day = program.day(for: weekday)!
            #expect(!day.poolA.isEmpty, "\(weekday) poolA")
            #expect(!day.poolB.isEmpty, "\(weekday) poolB")
        }
    }

    @Test func restDaysHaveNoPools() throws {
        let (program, _) = try makeProgram()
        for weekday: Weekday in [.thursday, .sunday] {
            let day = program.day(for: weekday)!
            #expect(day.poolA.isEmpty)
            #expect(day.poolB.isEmpty)
        }
    }

    /// Phase A and phase B must actually differ — otherwise there's no
    /// meaningful A/B split, just the same workout twice.
    @Test func phaseAAndPhaseBUseDifferentExercisesOnEveryLiftingDay() throws {
        let (program, _) = try makeProgram()
        for weekday: Weekday in [.monday, .tuesday, .wednesday, .friday] {
            let day = program.day(for: weekday)!
            let namesA = Set(day.poolA.compactMap { $0.exercise?.name })
            let namesB = Set(day.poolB.compactMap { $0.exercise?.name })
            #expect(namesA.isDisjoint(with: namesB), "\(weekday) A/B pools overlap")
        }
    }

    @Test func defaultsAreShoulderFocusAndTwoWeekCheckIn() throws {
        let (program, _) = try makeProgram()
        #expect(program.currentFocus == .shoulders)
        #expect(program.checkInIntervalDays == 14)
    }

    // MARK: - End-to-end: the seeded program is actually resolvable

    @Test func resolvesAFullTwoWeekCycleWithoutGaps() throws {
        let (program, _) = try makeProgram()
        let resolver = DayResolver(program: program)

        for weekOffset in 0..<2 {
            let calendar = PhaseCalculator.splitCalendar()
            let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: program.anchorDate)!
            for day in resolver.resolveWeek(containing: weekStart) {
                if day.isRest {
                    #expect(day.exercises.isEmpty)
                } else {
                    #expect(!day.exercises.isEmpty, "\(day.weekday) in week \(weekOffset) has no exercises")
                }
            }
        }
    }

    @Test func saturdayDoubleBorrowsTheOppositePhaseShoulderWorkFromTuesday() throws {
        let (program, _) = try makeProgram()
        let resolver = DayResolver(program: program, calendar: PhaseCalculator.splitCalendar())

        let calendar = PhaseCalculator.splitCalendar()
        let saturdayPhaseA = calendar.date(byAdding: .day, value: 5, to: program.anchorDate)!
        let resolved = resolver.resolve(for: saturdayPhaseA)

        #expect(resolved.phase == .a)
        #expect(resolved.sourcePhase == .b)
        #expect(resolved.focusGroup == .shoulders)
        let names = Set(resolved.exercises.compactMap { $0.exercise?.name })
        #expect(names == ["Push Press", "Arnold Press"])
    }
}
