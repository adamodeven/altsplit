import SwiftUI

/// The one box that swaps content based on state — but only content, never
/// footprint. Due: prompt to weigh in. Not due: current weight, trend, and
/// days until the next check-in.
struct CheckInBox: View {
    let program: Program
    let checkIns: [CheckIn] // sorted newest first
    let onTapDue: () -> Void
    let onTapNotDue: () -> Void

    private var calendar: Calendar { PhaseCalculator.splitCalendar() }

    private var cycleIndex: Int {
        PhaseCalculator.cycleIndex(on: .now, anchor: program.anchorDate, calendar: calendar)
    }

    private var isDue: Bool {
        PhaseCalculator.isCheckInDue(
            on: .now,
            anchor: program.anchorDate,
            completedCycleIndices: Set(checkIns.map(\.cycleIndex)),
            calendar: calendar
        )
    }

    private var latest: CheckIn? { checkIns.first }
    private var previous: CheckIn? { checkIns.dropFirst().first }

    var body: some View {
        Button(action: isDue ? onTapDue : onTapNotDue) {
            VStack(alignment: .leading, spacing: 4) {
                if isDue {
                    Text("WEIGH IN + PHOTO DUE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("Cycle \(cycleIndex + 1) · last: \(lastWeightSummary)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(currentWeightText)
                            .font(.title2)
                            .fontWeight(.bold)
                        trendIcon
                    }
                    Text(daysUntilNextText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(20)
            .contentShape(BentoBoxStyle.shape)
        }
        .buttonStyle(.plain)
        .frame(maxHeight: .infinity)
        .glassEffect(Glass.regular.interactive(), in: BentoBoxStyle.shape)
    }

    private var lastWeightSummary: String {
        guard let latest else { return "no data yet" }
        return String(format: "%.1f lb", latest.weightInPounds)
    }

    private var currentWeightText: String {
        guard let latest else { return "—" }
        return String(format: "%.1f lb", latest.weightInPounds)
    }

    @ViewBuilder
    private var trendIcon: some View {
        if let latest, let previous {
            let delta = latest.weightKilograms - previous.weightKilograms
            if abs(delta) < 0.05 {
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
            } else if delta > 0 {
                Image(systemName: "arrow.up.right").foregroundStyle(.orange)
            } else {
                Image(systemName: "arrow.down.right").foregroundStyle(.green)
            }
        }
    }

    private var daysUntilNextText: String {
        let next = PhaseCalculator.startOfNextCycle(after: .now, anchor: program.anchorDate, calendar: calendar)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: next).day ?? 0
        if days <= 0 { return "Next check-in today" }
        return days == 1 ? "1 day until next check-in" : "\(days) days until next check-in"
    }
}
