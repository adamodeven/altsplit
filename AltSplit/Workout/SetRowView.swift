import SwiftUI
import SwiftData
import UIKit

/// Which text field within a set row — used to route keyboard focus for
/// snapping the weight field's display back to its canonical value on blur.
enum SetField: Hashable {
    case weight(PersistentIdentifier)
    case reps(PersistentIdentifier)
    case duration(PersistentIdentifier)
}

/// One set of one exercise. Which fields show depends on `type` — the same
/// rule DESIGN.md sets for the typing model: type drives the logging UI.
struct SetRowView: View {
    @Bindable var entry: SetEntry
    let type: ExerciseType
    let unit: UnitMass
    /// Most recent completed set logged for this exercise, if any — shown
    /// as placeholder text so last time's numbers are visible without
    /// overwriting whatever the user actually types.
    let previous: SetEntry?
    /// Fired when the checkmark transitions to complete (not when undone),
    /// so the parent can kick off a rest timer.
    var onComplete: () -> Void = {}
    /// Fired when the checkmark transitions from complete back to
    /// incomplete, so the parent can cancel a rest timer it started.
    var onUncomplete: () -> Void = {}

    var focusedField: FocusState<SetField?>.Binding

    /// Bumped by the parent to shake this row — e.g. when Finish is tapped
    /// but this set is checked off without a weight/rep value logged.
    var shakeTrigger: Int = 0

    /// Local editing buffer for the weight field. Source of truth for what's
    /// on screen while typing — `weightBinding` only pushes to the model
    /// once the text parses as a full `Double`, so a partial number like a
    /// lone "." or "22." (before the digit after the decimal lands) stays
    /// on screen instead of being reformatted away by the model round-trip.
    @State private var weightText: String

    init(
        entry: SetEntry,
        type: ExerciseType,
        unit: UnitMass,
        previous: SetEntry?,
        onComplete: @escaping () -> Void = {},
        onUncomplete: @escaping () -> Void = {},
        focusedField: FocusState<SetField?>.Binding,
        shakeTrigger: Int = 0
    ) {
        self.entry = entry
        self.type = type
        self.unit = unit
        self.previous = previous
        self.onComplete = onComplete
        self.onUncomplete = onUncomplete
        self.focusedField = focusedField
        self.shakeTrigger = shakeTrigger
        _weightText = State(initialValue: entry.weight(in: unit).map { String(format: "%g", $0) } ?? "")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(entry.setIndex + 1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
                .accessibilityIdentifier("setLabel")

            fields

            Button {
                let wasComplete = entry.isComplete
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    entry.completedAt = wasComplete ? nil : .now
                }
                if !wasComplete { onComplete() } else { onUncomplete() }
            } label: {
                Image(systemName: entry.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(entry.isComplete ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: entry.isComplete)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("setCheckmark")
            .accessibilityAddTraits(entry.isComplete ? .isSelected : [])
        }
        .listRowBackground(rowFill)
        .shake(trigger: shakeTrigger)
        .sensoryFeedback(.success, trigger: entry.isComplete) { _, isComplete in isComplete }
        .onChange(of: unit) {
            weightText = entry.weight(in: unit).map { String(format: "%g", $0) } ?? ""
        }
        .onChange(of: focusedField.wrappedValue) { oldValue, newValue in
            // Snap the display back to the rounded/canonical value once the
            // user taps away, so ".5" settles to the actual stored increment.
            guard oldValue == .weight(entry.persistentModelID), newValue != oldValue else { return }
            weightText = entry.weight(in: unit).map { String(format: "%g", $0) } ?? ""
        }
    }

    /// Sweeps a tinted fill in from the trailing edge — where the checkmark
    /// button sits — when a set completes, so the fill reads as radiating
    /// out from the tap instead of an arbitrary left-to-right wipe.
    ///
    /// This scales rather than resizes: a `GeometryReader`-driven width
    /// inside `.listRowBackground` sets up a layout feedback loop (the row
    /// sizes itself from the background, the background sizes itself from
    /// the row) that crashed SwiftUI's AsyncRenderer outright. `scaleEffect`
    /// is a draw-time transform on a fixed-size shape, so there's no
    /// re-layout each frame.
    private var rowFill: some View {
        Rectangle()
            .fill(Color.accentColor.opacity(0.14))
            .scaleEffect(x: entry.isComplete ? 1 : 0, y: 1, anchor: .trailing)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: entry.isComplete)
    }

    @ViewBuilder
    private var fields: some View {
        switch type {
        case .lift:
            field(unit.symbol, text: weightBinding, prompt: previousWeightText, keyboard: .decimalPad, focusValue: .weight(entry.persistentModelID))
            Text("×").foregroundStyle(.secondary)
            field("reps", text: repsBinding, prompt: previousRepsText, keyboard: .numberPad, focusValue: .reps(entry.persistentModelID))

        case .bodyweight:
            field("reps", text: repsBinding, prompt: previousRepsText, keyboard: .numberPad, focusValue: .reps(entry.persistentModelID))
            Text("+").foregroundStyle(.secondary)
            field("\(unit.symbol) (opt.)", text: weightBinding, prompt: previousWeightText, keyboard: .decimalPad, focusValue: .weight(entry.persistentModelID))

        case .hold:
            field("sec", text: durationBinding, prompt: previousDurationText, keyboard: .numberPad, focusValue: .duration(entry.persistentModelID))
            Text("seconds").foregroundStyle(.secondary)
            Text("+").foregroundStyle(.secondary)
            field("\(unit.symbol) (opt.)", text: weightBinding, prompt: previousWeightText, keyboard: .decimalPad, focusValue: .weight(entry.persistentModelID))

        case .erg, .cardio:
            EmptyView()
        }
    }

    private var previousWeightText: String? { previous?.weight(in: unit).map { String(format: "%g", $0) } }
    private var previousRepsText: String? { previous?.reps.map(String.init) }
    private var previousDurationText: String? { previous?.duration.map { String(Int($0)) } }

    /// A text field whose actual tap-to-focus target reaches well past its
    /// drawn box, out into the dead space around it (HStack spacing, list
    /// row insets) — SwiftUI's native TextField only starts editing on a
    /// touch inside its literal glyph/frame bounds, and `contentShape`
    /// doesn't widen that for the underlying UIKit text control. So instead
    /// an invisible `Color.clear` is overlaid, expanded past the frame with
    /// negative padding, and a tap anywhere on it drives focus directly via
    /// `focusedField` — same effect as tapping the field, without touching
    /// anything that's actually drawn.
    private func field(
        _ title: String,
        text: Binding<String>,
        prompt: String?,
        keyboard: UIKeyboardType,
        focusValue: SetField
    ) -> some View {
        TextField(title, text: text, prompt: prompt.map { Text($0) })
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .focused(focusedField, equals: focusValue)
            .overlay {
                Color.clear
                    .contentShape(Rectangle())
                    .padding(.vertical, -14)
                    .padding(.horizontal, -8)
                    .onTapGesture { focusedField.wrappedValue = focusValue }
            }
    }

    // String-backed bindings so an empty field maps cleanly to `nil`
    // instead of relying on optional-numeric TextField formatting.

    private var weightBinding: Binding<String> {
        Binding(
            get: { weightText },
            set: { newValue in
                weightText = newValue
                if newValue.isEmpty {
                    entry.setWeight(nil, unit: unit)
                } else if let parsed = Double(newValue) {
                    entry.setWeight(parsed, unit: unit)
                }
                // else: not yet a complete number (e.g. ".", "22.", "-") —
                // keep the typed text on screen without touching the model
                // until it parses.
            }
        )
    }

    private var repsBinding: Binding<String> {
        Binding(
            get: { entry.reps.map(String.init) ?? "" },
            set: { entry.reps = Int($0) }
        )
    }

    private var durationBinding: Binding<String> {
        Binding(
            get: { entry.duration.map { String(Int($0)) } ?? "" },
            set: { entry.duration = $0.isEmpty ? nil : TimeInterval($0) }
        )
    }
}

/// A handful of quick left-right keyframes rather than a single spring —
/// explicit steps read as an unmistakable "no, look here" wiggle instead of
/// a subtle wobble that's easy to miss in a list of otherwise-still rows.
private struct ShakeModifier: ViewModifier {
    let trigger: Int
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, newValue in
                guard newValue != 0 else { return }
                let amount: CGFloat = 14
                let step = 0.06
                withAnimation(.linear(duration: step)) { offset = amount }
                withAnimation(.linear(duration: step).delay(step)) { offset = -amount }
                withAnimation(.linear(duration: step).delay(step * 2)) { offset = amount }
                withAnimation(.linear(duration: step).delay(step * 3)) { offset = -amount }
                withAnimation(.linear(duration: step).delay(step * 4)) { offset = 0 }
            }
    }
}

extension View {
    /// Shakes the view once each time `trigger` changes — used to draw
    /// attention to a set that's checked off but missing a required value.
    func shake(trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}
