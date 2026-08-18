import Foundation

/// Everything the UI needs to render a day, after phase and double
/// resolution have been applied.
struct ResolvedDay {
    let date: Date
    let weekday: Weekday
    let phase: Phase
    let slotKind: SlotKind
    let groups: [MuscleGroup]
    let exercises: [PlannedExercise]
    /// Set only when the day resolved as a double.
    let focusGroup: MuscleGroup?
    /// The phase the exercises were actually drawn from. Differs from `phase`
    /// on a double day.
    let sourcePhase: Phase

    var isRest: Bool { slotKind == .rest }
    var isDouble: Bool { slotKind == .double }

    var title: String {
        switch slotKind {
        case .rest: "Rest"
        case .double: focusGroup.map { "Double · \($0.displayName)" } ?? "Double"
        case .cardio where groups.isEmpty: "Erg"
        default:
            groups.isEmpty ? slotKind.displayName
                           : groups.map(\.displayName).joined(separator: " + ")
        }
    }

    var subtitle: String {
        guard !isRest else { return "No session scheduled" }
        guard !exercises.isEmpty else { return "Nothing planned yet" }
        let count = exercises.count
        let noun = count == 1 ? "exercise" : "exercises"
        guard let minutes = estimatedMinutes else { return "\(count) \(noun)" }
        return "\(count) \(noun) · ~\(minutes) min"
    }

    /// Rough working estimate: each set costs its rest plus about 40 seconds
    /// of work. Good enough to set expectations, not a prediction.
    var estimatedMinutes: Int? {
        guard !exercises.isEmpty else { return nil }
        let seconds = exercises.reduce(0.0) { total, planned in
            let perSet = Double(planned.restSeconds) + 40
            return total + Double(planned.targetSets) * perSet
        }
        return max(1, Int((seconds / 60).rounded()))
    }
}

/// Turns a `Program` plus a date into a concrete day.
///
/// The interesting rule lives in `resolveDouble`.
struct DayResolver {
    let program: Program
    let calendar: Calendar

    init(program: Program, calendar: Calendar = PhaseCalculator.splitCalendar()) {
        self.program = program
        self.calendar = PhaseCalculator.splitCalendar(from: calendar)
    }

    func resolve(for date: Date) -> ResolvedDay {
        let weekday = PhaseCalculator.weekday(for: date, calendar: calendar)
        let phase = PhaseCalculator.phase(on: date, anchor: program.anchorDate, calendar: calendar)

        guard let template = program.day(for: weekday) else {
            return ResolvedDay(
                date: date,
                weekday: weekday,
                phase: phase,
                slotKind: .rest,
                groups: [],
                exercises: [],
                focusGroup: nil,
                sourcePhase: phase
            )
        }

        switch template.slotKind {
        case .rest:
            return ResolvedDay(
                date: date,
                weekday: weekday,
                phase: phase,
                slotKind: .rest,
                groups: [],
                exercises: [],
                focusGroup: nil,
                sourcePhase: phase
            )

        case .double:
            return resolveDouble(template: template, date: date, weekday: weekday, phase: phase)

        case .lifting, .cardio:
            return ResolvedDay(
                date: date,
                weekday: weekday,
                phase: phase,
                slotKind: template.slotKind,
                groups: template.groups,
                exercises: template.pool(for: phase),
                focusGroup: nil,
                sourcePhase: phase
            )
        }
    }

    /// The double draws the **opposite phase's** work for the focused group.
    ///
    /// If it is an A week and the focus is shoulders, Saturday runs phase B's
    /// shoulder exercises. That needs no additional data entry and guarantees
    /// the extra volume is a different stimulus rather than a repeat of what
    /// was already done on Tuesday.
    private func resolveDouble(
        template: DayTemplate,
        date: Date,
        weekday: Weekday,
        phase: Phase
    ) -> ResolvedDay {
        let focus = program.currentFocus
        let sourcePhase = phase.other

        // The day that normally trains the focused group.
        let sourceDay = program.days.first { day in
            day.slotKind.isTrainingDay
                && day.slotKind != .double
                && day.groups.contains(focus)
        }

        let borrowed = sourceDay?
            .pool(for: sourcePhase)
            .filter { $0.exercise?.muscleGroup == focus } ?? []

        // Fall back to whatever the double day itself defines, so a focus
        // group with no matching source work still yields a session rather
        // than an empty screen.
        if borrowed.isEmpty {
            let own = template.pool(for: phase)
            return ResolvedDay(
                date: date,
                weekday: weekday,
                phase: phase,
                slotKind: .double,
                groups: template.groups.isEmpty ? [focus] : template.groups,
                exercises: own,
                focusGroup: focus,
                sourcePhase: phase
            )
        }

        return ResolvedDay(
            date: date,
            weekday: weekday,
            phase: phase,
            slotKind: .double,
            groups: [focus],
            exercises: borrowed,
            focusGroup: focus,
            sourcePhase: sourcePhase
        )
    }

    /// Every day of the week containing `date`, in Monday-first order.
    func resolveWeek(containing date: Date) -> [ResolvedDay] {
        let start = PhaseCalculator.startOfWeek(for: date, calendar: calendar)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).map(resolve(for:))
        }
    }

    var isFocusStale: Bool {
        let weeks = PhaseCalculator.weeksSinceAnchor(
            .now,
            anchor: program.focusConfirmedAt,
            calendar: calendar
        )
        return weeks >= 4
    }
}
