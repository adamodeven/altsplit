import Testing
import Foundation
import SwiftData
@testable import AltSplit

@MainActor
struct BadgeUpdaterTests {
    struct Fixture {
        let program: Program
        let calendar: Calendar
    }

    func makeFixture() throws -> Fixture {
        let schema = Schema([
            Program.self, DayTemplate.self, Exercise.self, PlannedExercise.self,
            WorkoutSession.self, SetEntry.self, CardioResult.self,
            CheckIn.self, SupplementLog.self, SnoozeRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let exercises = ExerciseLibrary.seed(into: context)
        let calendar = PhaseCalculator.splitCalendar()
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))! // Monday
        let program = DefaultProgram.seed(context: context, exercises: exercises, anchorDate: anchor)
        try context.save()

        return Fixture(program: program, calendar: calendar)
    }

    @Test func freshTrainingDayHasFourOpenItems() throws {
        let fixture = try makeFixture()
        let monday = fixture.program.anchorDate // training day: biceps + back

        let count = BadgeUpdater.openItemsCount(
            program: fixture.program,
            sessions: [],
            supplementLogs: [],
            checkIns: [],
            now: monday,
            calendar: fixture.calendar
        )
        #expect(count == 4)
    }

    @Test func restDayExcludesWorkoutFromOpenItems() throws {
        let fixture = try makeFixture()
        let thursday = fixture.calendar.date(byAdding: .day, value: 3, to: fixture.program.anchorDate)!

        let count = BadgeUpdater.openItemsCount(
            program: fixture.program,
            sessions: [],
            supplementLogs: [],
            checkIns: [],
            now: thursday,
            calendar: fixture.calendar
        )
        #expect(count == 3) // protein, creatine, check-in — no workout
    }

    @Test func everythingDoneMeansZeroOpenItems() throws {
        let fixture = try makeFixture()
        let monday = fixture.program.anchorDate

        let session = WorkoutSession(date: monday, phase: .a, weekday: .monday, status: .completed)
        let supplementLog = SupplementLog(day: fixture.calendar.startOfDay(for: monday), protein: true, creatine: true)
        let checkIn = CheckIn(date: monday, weightKilograms: 82, photoRef: "x.jpg", cycleIndex: 0)

        let count = BadgeUpdater.openItemsCount(
            program: fixture.program,
            sessions: [session],
            supplementLogs: [supplementLog],
            checkIns: [checkIn],
            now: monday,
            calendar: fixture.calendar
        )
        #expect(count == 0)
    }

    @Test func checkInAlreadyDoneThisCycleIsNotCountedAsOpen() throws {
        let fixture = try makeFixture()
        let monday = fixture.program.anchorDate
        let checkIn = CheckIn(date: monday, weightKilograms: 82, photoRef: "x.jpg", cycleIndex: 0)

        let count = BadgeUpdater.openItemsCount(
            program: fixture.program,
            sessions: [],
            supplementLogs: [],
            checkIns: [checkIn],
            now: monday,
            calendar: fixture.calendar
        )
        #expect(count == 3) // workout, protein, creatine — check-in already logged
    }

    @Test func onlyOneSupplementTakenLeavesOneOpen() throws {
        let fixture = try makeFixture()
        let monday = fixture.program.anchorDate
        let session = WorkoutSession(date: monday, phase: .a, weekday: .monday, status: .completed)
        let checkIn = CheckIn(date: monday, weightKilograms: 82, photoRef: "x.jpg", cycleIndex: 0)
        let supplementLog = SupplementLog(day: fixture.calendar.startOfDay(for: monday), protein: true, creatine: false)

        let count = BadgeUpdater.openItemsCount(
            program: fixture.program,
            sessions: [session],
            supplementLogs: [supplementLog],
            checkIns: [checkIn],
            now: monday,
            calendar: fixture.calendar
        )
        #expect(count == 1) // creatine only
    }
}
