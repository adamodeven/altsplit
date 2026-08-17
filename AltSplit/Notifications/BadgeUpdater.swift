import Foundation
import SwiftData
import UserNotifications

/// Badge count = open items today: workout not logged, supplements not
/// taken, check-in due.
enum BadgeUpdater {
    /// Pure computation, separated from the `setBadgeCount` side effect so
    /// it's unit-testable without a live notification authorization.
    static func openItemsCount(
        program: Program,
        sessions: [WorkoutSession],
        supplementLogs: [SupplementLog],
        checkIns: [CheckIn],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let startOfToday = calendar.startOfDay(for: now)

        let today = DayResolver(program: program).resolve(for: now)
        let loggedToday = sessions.contains { calendar.isDate($0.date, inSameDayAs: startOfToday) }
        let todaysLog = supplementLogs.first { calendar.isDate($0.day, inSameDayAs: startOfToday) }

        let completedCycles = Set(checkIns.map(\.cycleIndex))
        let checkInDue = PhaseCalculator.isCheckInDue(
            on: now,
            anchor: program.anchorDate,
            completedCycleIndices: completedCycles
        )

        var openItems = 0
        if !today.isRest && !loggedToday { openItems += 1 }
        if !(todaysLog?.protein ?? false) { openItems += 1 }
        if !(todaysLog?.creatine ?? false) { openItems += 1 }
        if checkInDue { openItems += 1 }
        return openItems
    }

    @MainActor
    static func refresh(context: ModelContext) async {
        guard let program = try? context.fetch(FetchDescriptor<Program>()).first else { return }

        let count = openItemsCount(
            program: program,
            sessions: (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? [],
            supplementLogs: (try? context.fetch(FetchDescriptor<SupplementLog>())) ?? [],
            checkIns: (try? context.fetch(FetchDescriptor<CheckIn>())) ?? []
        )

        try? await UNUserNotificationCenter.current().setBadgeCount(count)
    }
}
