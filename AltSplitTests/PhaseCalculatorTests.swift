import Testing
import Foundation
@testable import AltSplit

struct PhaseCalculatorTests {

    // MARK: - Fixtures

    /// UTC calendar, first weekday forced to Monday by `splitCalendar`.
    var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return PhaseCalculator.splitCalendar(from: calendar)
    }

    func date(
        _ year: Int, _ month: Int, _ day: Int,
        hour: Int = 0, minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    /// Monday, Jan 5 2026 — the anchor week, defined to be phase A.
    var anchor: Date { date(2026, 1, 5, calendar: utcCalendar) }

    // MARK: - A/B alternation, many weeks forward and backward

    @Test func anchorWeekIsPhaseA() {
        #expect(PhaseCalculator.phase(on: anchor, anchor: anchor, calendar: utcCalendar) == .a)
    }

    @Test("phase alternates every week across a long forward span", arguments: 0..<104)
    func alternatesForward(weekOffset: Int) {
        let calendar = utcCalendar
        let day = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: anchor)!
        // Independent check: whether weekOffset is even, not routed through
        // PhaseCalculator's own flooredMod.
        let expected: Phase = weekOffset.isMultiple(of: 2) ? .a : .b
        #expect(PhaseCalculator.phase(on: day, anchor: anchor, calendar: calendar) == expected)
    }

    @Test("phase alternates every week across a long backward span (before the anchor)", arguments: -104..<0)
    func alternatesBackward(weekOffset: Int) {
        let calendar = utcCalendar
        let day = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: anchor)!
        let expected: Phase = weekOffset.isMultiple(of: 2) ? .a : .b
        #expect(PhaseCalculator.phase(on: day, anchor: anchor, calendar: calendar) == expected)
    }

    @Test("any day within a week resolves to that week's phase, not just Monday", arguments: -10..<10)
    func wholeWeekSharesPhase(weekOffset: Int) {
        let calendar = utcCalendar
        let monday = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: anchor)!
        let expected = PhaseCalculator.phase(on: monday, anchor: anchor, calendar: calendar)
        for dayOffset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
            #expect(PhaseCalculator.phase(on: day, anchor: anchor, calendar: calendar) == expected)
        }
    }

    // MARK: - Dates before the anchor (negative weeks / flooredMod)

    @Test func weeksSinceAnchorIsNegativeBeforeAnchor() {
        let calendar = utcCalendar
        let oneWeekEarlier = calendar.date(byAdding: .weekOfYear, value: -1, to: anchor)!
        let twoWeeksEarlier = calendar.date(byAdding: .weekOfYear, value: -2, to: anchor)!

        #expect(PhaseCalculator.weeksSinceAnchor(anchor, anchor: anchor, calendar: calendar) == 0)
        #expect(PhaseCalculator.weeksSinceAnchor(oneWeekEarlier, anchor: anchor, calendar: calendar) == -1)
        #expect(PhaseCalculator.weeksSinceAnchor(twoWeeksEarlier, anchor: anchor, calendar: calendar) == -2)
    }

    @Test func phaseImmediatelyBeforeAnchorIsB() {
        // Anchor week is A, so the week before it must be B, not A again —
        // this is exactly the case native `%` gets wrong for negative values.
        let calendar = utcCalendar
        let oneWeekEarlier = calendar.date(byAdding: .weekOfYear, value: -1, to: anchor)!
        #expect(PhaseCalculator.phase(on: oneWeekEarlier, anchor: anchor, calendar: calendar) == .b)
    }

    @Test func flooredModHandlesNegativeValues() {
        #expect((-1).flooredMod(2) == 1)
        #expect((-2).flooredMod(2) == 0)
        #expect((-3).flooredMod(2) == 1)
        #expect((-4).flooredMod(2) == 0)
        #expect(0.flooredMod(2) == 0)
        #expect(1.flooredMod(2) == 1)
    }

    // MARK: - Year boundaries

    @Test func phaseIsConsistentAcrossNewYearBoundary() {
        let calendar = utcCalendar
        // Anchor in late December 2025, phase A.
        let decemberAnchor = date(2025, 12, 29, calendar: calendar) // Monday
        let oneWeekIntoJanuary = date(2026, 1, 5, calendar: calendar) // Monday
        let twoWeeksIntoJanuary = date(2026, 1, 12, calendar: calendar) // Monday

        #expect(PhaseCalculator.phase(on: decemberAnchor, anchor: decemberAnchor, calendar: calendar) == .a)
        #expect(PhaseCalculator.phase(on: oneWeekIntoJanuary, anchor: decemberAnchor, calendar: calendar) == .b)
        #expect(PhaseCalculator.phase(on: twoWeeksIntoJanuary, anchor: decemberAnchor, calendar: calendar) == .a)
    }

    @Test func weeksSinceAnchorCrossesYearBoundaryCorrectly() {
        let calendar = utcCalendar
        let decemberAnchor = date(2025, 12, 29, calendar: calendar)
        let januaryDate = date(2026, 1, 12, calendar: calendar)
        #expect(PhaseCalculator.weeksSinceAnchor(januaryDate, anchor: decemberAnchor, calendar: calendar) == 2)
    }

    @Test func cycleIndexCrossesYearBoundaryCorrectly() {
        let calendar = utcCalendar
        // Anchor is the last cycle of 2025; four weeks later is the next
        // cycle, now in 2026.
        let decemberAnchor = date(2025, 12, 29, calendar: calendar)
        let nextCycleStart = date(2026, 1, 12, calendar: calendar)
        #expect(PhaseCalculator.cycleIndex(on: decemberAnchor, anchor: decemberAnchor, calendar: calendar) == 0)
        #expect(PhaseCalculator.cycleIndex(on: nextCycleStart, anchor: decemberAnchor, calendar: calendar) == 1)
    }

    // MARK: - DST transitions

    /// Spring-forward: America/New_York loses an hour on the second Sunday
    /// in March. 2026's transition is Sunday March 8.
    @Test func phaseSurvivesSpringForwardTransition() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar = PhaseCalculator.splitCalendar(from: calendar)

        let beforeDST = date(2026, 3, 2, calendar: calendar) // Monday, phase A
        let afterDST = date(2026, 3, 9, calendar: calendar)  // Monday, one week later, spans the DST jump

        #expect(PhaseCalculator.phase(on: beforeDST, anchor: beforeDST, calendar: calendar) == .a)
        #expect(PhaseCalculator.phase(on: afterDST, anchor: beforeDST, calendar: calendar) == .b)
        #expect(PhaseCalculator.weeksSinceAnchor(afterDST, anchor: beforeDST, calendar: calendar) == 1)
    }

    /// Fall-back: America/New_York gains an hour on the first Sunday in
    /// November. 2026's transition is Sunday November 1.
    @Test func phaseSurvivesFallBackTransition() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar = PhaseCalculator.splitCalendar(from: calendar)

        let beforeDST = date(2026, 10, 26, calendar: calendar) // Monday, phase A
        let afterDST = date(2026, 11, 2, calendar: calendar)   // Monday, one week later, spans the fall-back

        #expect(PhaseCalculator.phase(on: beforeDST, anchor: beforeDST, calendar: calendar) == .a)
        #expect(PhaseCalculator.phase(on: afterDST, anchor: beforeDST, calendar: calendar) == .b)
        #expect(PhaseCalculator.weeksSinceAnchor(afterDST, anchor: beforeDST, calendar: calendar) == 1)
    }

    @Test func timeOfDayOnDSTTransitionDayDoesNotAffectPhase() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar = PhaseCalculator.splitCalendar(from: calendar)

        let anchor = date(2026, 3, 2, calendar: calendar) // Monday, phase A
        // Sunday March 8, 2026 is the spring-forward day itself; 2:30am
        // local time does not exist that day, so exercise a late-evening
        // and an early-morning timestamp on either side of the gap.
        let lateOnTransitionDay = date(2026, 3, 8, hour: 23, minute: 0, calendar: calendar)
        let earlyOnTransitionDay = date(2026, 3, 8, hour: 4, minute: 0, calendar: calendar)

        #expect(PhaseCalculator.phase(on: lateOnTransitionDay, anchor: anchor, calendar: calendar) == .a)
        #expect(PhaseCalculator.phase(on: earlyOnTransitionDay, anchor: anchor, calendar: calendar) == .a)
    }

    // MARK: - cycleIndex / startOfCycle agreement

    @Test("startOfCycle always resolves to a phase-A Monday", arguments: -30..<30)
    func startOfCycleIsAlwaysPhaseA(weekOffset: Int) {
        let calendar = utcCalendar
        let day = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: anchor)!
        let cycleStart = PhaseCalculator.startOfCycle(containing: day, anchor: anchor, calendar: calendar)
        #expect(PhaseCalculator.phase(on: cycleStart, anchor: anchor, calendar: calendar) == .a)
        #expect(PhaseCalculator.weekday(for: cycleStart, calendar: calendar) == .monday)
    }

    @Test(
        "cycleIndex(on: startOfCycle(containing: date)) == cycleIndex(on: date)",
        arguments: -30..<30
    )
    func cycleIndexAgreesWithStartOfCycle(weekOffset: Int) {
        let calendar = utcCalendar
        let day = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: anchor)!
        let cycleStart = PhaseCalculator.startOfCycle(containing: day, anchor: anchor, calendar: calendar)

        let indexFromDay = PhaseCalculator.cycleIndex(on: day, anchor: anchor, calendar: calendar)
        let indexFromCycleStart = PhaseCalculator.cycleIndex(on: cycleStart, anchor: anchor, calendar: calendar)
        #expect(indexFromDay == indexFromCycleStart)
    }

    @Test("every day within a cycle shares the same cycleIndex and startOfCycle", arguments: -10..<10)
    func wholeCycleSharesIndexAndStart(cycleOffset: Int) {
        let calendar = utcCalendar
        let cycleAnchor = calendar.date(byAdding: .weekOfYear, value: cycleOffset * 2, to: anchor)!
        let expectedIndex = PhaseCalculator.cycleIndex(on: cycleAnchor, anchor: anchor, calendar: calendar)
        let expectedStart = PhaseCalculator.startOfCycle(containing: cycleAnchor, anchor: anchor, calendar: calendar)

        for dayOffset in 0..<14 {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: cycleAnchor)!
            #expect(PhaseCalculator.cycleIndex(on: day, anchor: anchor, calendar: calendar) == expectedIndex)
            #expect(PhaseCalculator.startOfCycle(containing: day, anchor: anchor, calendar: calendar) == expectedStart)
        }
    }

    @Test func startOfNextCycleIsTwoWeeksAfterStartOfCycle() {
        let calendar = utcCalendar
        let start = PhaseCalculator.startOfCycle(containing: anchor, anchor: anchor, calendar: calendar)
        let next = PhaseCalculator.startOfNextCycle(after: anchor, anchor: anchor, calendar: calendar)
        let expectedNext = calendar.date(byAdding: .weekOfYear, value: 2, to: start)!
        #expect(next == expectedNext)
        // And it must itself be a valid, phase-A cycle start.
        #expect(PhaseCalculator.startOfCycle(containing: next, anchor: anchor, calendar: calendar) == next)
    }

    @Test("startOfCycle is idempotent for dates already at a cycle start", arguments: -10..<10)
    func startOfCycleIsIdempotent(cycleOffset: Int) {
        let calendar = utcCalendar
        let cycleStart = calendar.date(byAdding: .weekOfYear, value: cycleOffset * 2, to: anchor)!
        #expect(PhaseCalculator.startOfCycle(containing: cycleStart, anchor: anchor, calendar: calendar) == cycleStart)
    }
}
