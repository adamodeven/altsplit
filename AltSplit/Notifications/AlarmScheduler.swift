import AlarmKit
import AppIntents
import Foundation
import SwiftUI

/// AlarmKit alarms — the hard tier. They break through silent mode and
/// Focus, unlike a standard notification, which is why they're reserved for
/// the two things that must not be missed: starting a workout and the
/// weigh-in morning.
struct WorkoutAlarmMetadata: AlarmMetadata {}

@MainActor
enum AlarmScheduler {
    /// Fixed IDs so rescheduling replaces the existing alarm rather than
    /// piling up duplicates.
    private static let workoutAlarmID = UUID(uuidString: "9C6E1B9A-9A6E-4B7B-8F1D-0B7B6B6B6B01")!
    private static let weighInAlarmID = UUID(uuidString: "9C6E1B9A-9A6E-4B7B-8F1D-0B7B6B6B6B02")!

    private static let workoutHour = 7
    private static let workoutMinute = 0

    static func rescheduleAll(program: Program) async {
        let state: AlarmManager.AuthorizationState
        if AlarmManager.shared.authorizationState == .notDetermined {
            state = (try? await AlarmManager.shared.requestAuthorization()) ?? .denied
        } else {
            state = AlarmManager.shared.authorizationState
        }
        guard state == .authorized else { return }

        await scheduleWorkoutAlarm(program: program)
        await scheduleWeighInAlarm(program: program)
    }

    private static func scheduleWorkoutAlarm(program: Program) async {
        let trainingWeekdays = program.days
            .filter { $0.slotKind.isTrainingDay }
            .map { $0.weekday.localeWeekday }
        guard !trainingWeekdays.isEmpty else { return }

        let time = Alarm.Schedule.Relative.Time(hour: workoutHour, minute: workoutMinute)
        let recurrence = Alarm.Schedule.Relative(time: time, repeats: .weekly(trainingWeekdays))
        let schedule = Alarm.Schedule.relative(recurrence)

        let attributes = AlarmAttributes<WorkoutAlarmMetadata>(
            presentation: AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: "Workout Time",
                    stopButton: AlarmButton(text: "Open AltSplit", textColor: .white, systemImageName: "figure.strengthtraining.traditional")
                )
            ),
            metadata: WorkoutAlarmMetadata(),
            tintColor: .accentColor
        )

        try? AlarmManager.shared.cancel(id: workoutAlarmID)
        _ = try? await AlarmManager.shared.schedule(
            id: workoutAlarmID,
            configuration: .alarm(schedule: schedule, attributes: attributes)
        )
    }

    /// Every 2 weeks (start of each A-week) rather than weekly, which
    /// AlarmKit's own recurrence can't express — scheduled as a one-off
    /// fixed-date alarm for the next occurrence and re-derived on every
    /// launch via `rescheduleAll`.
    private static func scheduleWeighInAlarm(program: Program) async {
        let calendar = PhaseCalculator.splitCalendar()
        let now = Date.now

        var checkInMonday = PhaseCalculator.checkInDate(
            forCycleContaining: now,
            anchor: program.anchorDate,
            calendar: calendar
        )
        if let passed = calendar.date(bySettingHour: workoutHour, minute: workoutMinute, second: 0, of: checkInMonday),
           passed < now {
            checkInMonday = PhaseCalculator.startOfNextCycle(after: now, anchor: program.anchorDate, calendar: calendar)
        }
        guard let fireDate = calendar.date(bySettingHour: workoutHour, minute: workoutMinute, second: 0, of: checkInMonday) else {
            return
        }

        let attributes = AlarmAttributes<WorkoutAlarmMetadata>(
            presentation: AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: "Weigh-In + Photo Day",
                    stopButton: AlarmButton(text: "Open AltSplit", textColor: .white, systemImageName: "camera.fill")
                )
            ),
            metadata: WorkoutAlarmMetadata(),
            tintColor: .accentColor
        )

        try? AlarmManager.shared.cancel(id: weighInAlarmID)
        _ = try? await AlarmManager.shared.schedule(
            id: weighInAlarmID,
            configuration: .alarm(schedule: .fixed(fireDate), attributes: attributes)
        )
    }
}
