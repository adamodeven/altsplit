import Foundation

/// Pure date maths for the two-week alternation.
///
/// Deliberately free of SwiftData and SwiftUI so the rules that decide *what
/// you are training today* can be unit tested in isolation. Every function
/// here is a pure function of its inputs.
enum PhaseCalculator {

    /// The split is written Monday-first, so week boundaries are forced to
    /// Monday regardless of the device locale.
    static func splitCalendar(from base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2
        return calendar
    }

    /// Monday 00:00 of the week containing `date`.
    static func startOfWeek(for date: Date, calendar: Calendar = splitCalendar()) -> Date {
        let calendar = splitCalendar(from: calendar)
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    /// Whole weeks from `anchor`'s week to `date`'s week. Negative when
    /// `date` precedes `anchor`.
    static func weeksSinceAnchor(
        _ date: Date,
        anchor: Date,
        calendar: Calendar = splitCalendar()
    ) -> Int {
        let calendar = splitCalendar(from: calendar)
        let from = startOfWeek(for: anchor, calendar: calendar)
        let to = startOfWeek(for: date, calendar: calendar)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        // Both operands are week starts, so this divides evenly; `floor`
        // keeps the negative side correct rather than truncating toward zero.
        return Int((Double(days) / 7.0).rounded(.down))
    }

    /// Which phase `date` falls in.
    ///
    /// Calendar-anchored by design: skipping a week does not shift the
    /// schedule, it just produces a missed session. The rhythm is the point.
    static func phase(
        on date: Date,
        anchor: Date,
        calendar: Calendar = splitCalendar()
    ) -> Phase {
        let weeks = weeksSinceAnchor(date, anchor: anchor, calendar: calendar)
        return weeks.flooredMod(2) == 0 ? .a : .b
    }

    /// 0-based index of the two-week cycle containing `date`. Cycle 0 starts
    /// at the anchor week.
    static func cycleIndex(
        on date: Date,
        anchor: Date,
        calendar: Calendar = splitCalendar()
    ) -> Int {
        let weeks = weeksSinceAnchor(date, anchor: anchor, calendar: calendar)
        return Int((Double(weeks) / 2.0).rounded(.down))
    }

    /// Monday of the A-week that opens the cycle containing `date`.
    static func startOfCycle(
        containing date: Date,
        anchor: Date,
        calendar: Calendar = splitCalendar()
    ) -> Date {
        let calendar = splitCalendar(from: calendar)
        let index = cycleIndex(on: date, anchor: anchor, calendar: calendar)
        let anchorWeekStart = startOfWeek(for: anchor, calendar: calendar)
        return calendar.date(byAdding: .weekOfYear, value: index * 2, to: anchorWeekStart)
            ?? anchorWeekStart
    }

    /// Monday of the next cycle after the one containing `date`.
    static func startOfNextCycle(
        after date: Date,
        anchor: Date,
        calendar: Calendar = splitCalendar()
    ) -> Date {
        let calendar = splitCalendar(from: calendar)
        let current = startOfCycle(containing: date, anchor: anchor, calendar: calendar)
        return calendar.date(byAdding: .weekOfYear, value: 2, to: current) ?? current
    }

    /// Check-ins land on the Monday that opens each cycle, so every photo is
    /// implicitly labelled "start of cycle N" and the timeline is evenly
    /// spaced without any extra bookkeeping.
    static func checkInDate(
        forCycleContaining date: Date,
        anchor: Date,
        calendar: Calendar = splitCalendar()
    ) -> Date {
        startOfCycle(containing: date, anchor: anchor, calendar: calendar)
    }

    /// True when this cycle's check-in has not been recorded yet.
    static func isCheckInDue(
        on date: Date,
        anchor: Date,
        completedCycleIndices: Set<Int>,
        calendar: Calendar = splitCalendar()
    ) -> Bool {
        let index = cycleIndex(on: date, anchor: anchor, calendar: calendar)
        return !completedCycleIndices.contains(index)
    }

    static func weekday(for date: Date, calendar: Calendar = splitCalendar()) -> Weekday {
        let calendar = splitCalendar(from: calendar)
        let component = calendar.component(.weekday, from: date)
        return Weekday(calendarWeekday: component) ?? .monday
    }
}

extension Int {
    /// `%` in Swift keeps the sign of the dividend, which breaks phase
    /// resolution for dates before the anchor.
    func flooredMod(_ modulus: Int) -> Int {
        precondition(modulus > 0, "modulus must be positive")
        let remainder = self % modulus
        return remainder < 0 ? remainder + modulus : remainder
    }
}
