import Foundation
import SwiftData

/// Single entry point that ties the badge, notifications, and AlarmKit
/// alarms together. Permission-requesting calls are skipped under UI
/// testing so automated runs never hit a system permission sheet.
enum AccountabilityCoordinator {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_RESET")
    }

    /// Run once at launch: requests permissions, (re)schedules every
    /// recurring notification and alarm, and sets the badge.
    @MainActor
    static func refreshAll(program: Program, context: ModelContext) async {
        await BadgeUpdater.refresh(context: context)
        guard !isUITesting else { return }

        await NotificationScheduler.requestAuthorizationIfNeeded()
        NotificationScheduler.registerCategories()
        NotificationScheduler.scheduleSupplementReminder()
        NotificationScheduler.scheduleFocusReconfirmation(program: program)
        NotificationScheduler.scheduleCycleReview(program: program)

        await AlarmScheduler.rescheduleAll(program: program)
    }

    /// Run after anything that changes today's open-item count (a
    /// supplement toggle, finishing a workout, saving a check-in) — cheap
    /// enough to call liberally, unlike `refreshAll`.
    @MainActor
    static func refreshBadge(context: ModelContext) async {
        await BadgeUpdater.refresh(context: context)
    }
}
