import SwiftUI

/// Full-width box. Tap goes straight into the active workout logger — no
/// intermediate confirm screen. Long press previews the day's exercises.
/// Tinted on a training day, untinted on a rest day: colour carries the
/// state, geometry never moves.
struct WorkoutBox: View {
    let day: ResolvedDay
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(day.title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(day.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(20)
            .contentShape(BentoBoxStyle.shape)
        }
        .buttonStyle(.plain)
        .frame(maxHeight: .infinity)
        .glassEffect(glass, in: BentoBoxStyle.shape)
        .contextMenu {
            Button(action: onTap) {
                Label("Start Workout", systemImage: "play.fill")
            }
        } preview: {
            WorkoutPreviewList(day: day)
        }
    }

    private var headline: String {
        "\(day.phase.displayName.uppercased()) · \(day.weekday.displayName.uppercased())"
    }

    private var glass: Glass {
        let base = Glass.regular.interactive()
        return day.isRest ? base : base.tint(.accentColor)
    }
}
