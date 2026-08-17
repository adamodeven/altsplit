import Foundation
import UserNotifications

/// Standard notifications — the soft tier. Deserve a nudge, not a klaxon.
enum NotificationScheduler {
    enum Category: String {
        case supplementReminder = "SUPPLEMENT_REMINDER"
    }

    enum Action: String {
        case markProteinTaken = "MARK_PROTEIN_TAKEN"
        case markCreatineTaken = "MARK_CREATINE_TAKEN"
    }

    static let supplementReminderID = "supplementReminder"
    static let focusReconfirmID = "focusReconfirm"
    static let cycleReviewID = "cycleReview"

    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Lets protein/creatine be checked off directly from the notification,
    /// no launch required.
    static func registerCategories() {
        let protein = UNNotificationAction(
            identifier: Action.markProteinTaken.rawValue,
            title: "Mark Protein Taken",
            options: []
        )
        let creatine = UNNotificationAction(
            identifier: Action.markCreatineTaken.rawValue,
            title: "Mark Creatine Taken",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Category.supplementReminder.rawValue,
            actions: [protein, creatine],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func scheduleSupplementReminder(hour: Int = 20, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "Evening Check-In"
        content.body = "Log your protein and creatine for today."
        content.categoryIdentifier = Category.supplementReminder.rawValue
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: supplementReminderID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// The focus prompts to reconfirm every 4 weeks so it can't go stale
    /// unnoticed.
    static func scheduleFocusReconfirmation(program: Program) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [focusReconfirmID])

        guard let fireDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: program.focusConfirmedAt),
              fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reconfirm Your Focus"
        content.body = "It's been 4 weeks — is \(program.currentFocus.displayName) still the right double-day focus?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: focusReconfirmID, content: content, trigger: trigger)
        center.add(request)
    }

    static func scheduleCycleReview(program: Program) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [cycleReviewID])

        let calendar = PhaseCalculator.splitCalendar()
        let nextCycleStart = PhaseCalculator.startOfNextCycle(after: .now, anchor: program.anchorDate, calendar: calendar)
        guard let fireDate = calendar.date(byAdding: .day, value: -1, to: nextCycleStart), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Cycle Review"
        content.body = "Two weeks down. Check your Progress tab before the next cycle starts."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: cycleReviewID, content: content, trigger: trigger)
        center.add(request)
    }
}
