import SwiftUI

/// Full-width box. Tap goes straight into the active workout logger — no
/// intermediate confirm screen. Long press previews the day's exercises.
/// Tinted on a training day, untinted on a rest day: colour carries the
/// state, geometry never moves.
struct WorkoutBox: View {
    let day: ResolvedDay
    let onTap: () -> Void

    var body: some View {
        // `.glassEffect(_:in:)` swallows the touch it needs itself to
        // render the material, which starves the long-press recognizer
        // `.contextMenu(preview:)` needs — holding down did nothing (or,
        // combined with a `Button`, fired the tap instead of previewing).
        // Putting the glass on a *background* shape didn't help either:
        // `GlassEffectContainer` blurs across the whole registered
        // element's bounds, not strictly behind it, so the text came out
        // frosted too. Instead, the card renders exactly as it did before
        // (untouched, crisp), and a transparent sibling on top owns the
        // gestures — nothing about it is glass, so it doesn't compete for
        // the touch, and it doesn't register with the container to blur.
        ZStack(alignment: .leading) {
            card

            Color.clear
                .contentShape(BentoBoxStyle.shape)
                .contextMenu {
                    Button(action: onTap) {
                        Label("Start Workout", systemImage: "play.fill")
                    }
                } preview: {
                    WorkoutPreviewList(day: day)
                }
                .onTapGesture(perform: onTap)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var card: some View {
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
        .glassEffect(glass, in: BentoBoxStyle.shape)
    }

    private var headline: String {
        "\(day.phase.displayName.uppercased()) · \(day.weekday.displayName.uppercased())"
    }

    private var glass: Glass {
        let base = Glass.regular.interactive()
        return day.isRest ? base : base.tint(.accentColor)
    }
}
