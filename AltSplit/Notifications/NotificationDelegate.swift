import Foundation
import SwiftData
import UserNotifications

/// Handles the supplement notification actions so protein/creatine can be
/// checked off directly from the notification, and shows banners even in
/// the foreground.
///
/// The class is `@MainActor` for its SwiftData work, but the two protocol
/// witnesses must stay `nonisolated` — `UNUserNotificationCenterDelegate`'s
/// requirements take non-Sendable parameters, which an isolated
/// implementation can't accept directly. Each witness pulls out only the
/// Sendable bit it needs before hopping back to the main actor.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await handle(actionIdentifier: response.actionIdentifier)
    }

    private func handle(actionIdentifier: String) async {
        let context = ModelContext(modelContainer)
        let today = Calendar.current.startOfDay(for: .now)

        switch actionIdentifier {
        case NotificationScheduler.Action.markProteinTaken.rawValue:
            Self.setSupplementFlag(\.protein, day: today, context: context)
        case NotificationScheduler.Action.markCreatineTaken.rawValue:
            Self.setSupplementFlag(\.creatine, day: today, context: context)
        default:
            break
        }

        try? context.save()
        await BadgeUpdater.refresh(context: context)
    }

    private static func setSupplementFlag(
        _ keyPath: ReferenceWritableKeyPath<SupplementLog, Bool>,
        day: Date,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        let existing = (try? context.fetch(FetchDescriptor<SupplementLog>()))?
            .first { calendar.isDate($0.day, inSameDayAs: day) }
        let log = existing ?? {
            let new = SupplementLog(day: day)
            context.insert(new)
            return new
        }()
        log[keyPath: keyPath] = true
    }
}
