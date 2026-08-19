import SwiftUI
import SwiftData
import UIKit

/// Which text field within a set row — used to route keyboard focus so the
/// "Next" accessory can walk straight through every open field in the
/// session, since number pads have no built-in return key to do it for us.
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
    /// Most recent completed set logged for this exercise, if any — shown
    /// as placeholder text so last time's numbers are visible without
    /// overwriting whatever the user actually types.
    let previous: SetEntry?
    /// Fired when the checkmark transitions to complete (not when undone),
    /// so the parent can kick off a rest timer.
    var onComplete: () -> Void = {}

    var focusedField: FocusState<SetField?>.Binding

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(entry.setIndex + 1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            fields

            Spacer()

            Button {
                let wasComplete = entry.isComplete
                entry.completedAt = wasComplete ? nil : .now
                if !wasComplete { onComplete() }
            } label: {
                Image(systemName: entry.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(entry.isComplete ? .green : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("setCheckmark")
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch type {
        case .lift:
            field("lb", text: weightBinding, prompt: previousWeightText, keyboard: .decimalPad, width: 72)
                .focused(focusedField, equals: .weight(entry.persistentModelID))
            Text("×").foregroundStyle(.secondary)
            field("reps", text: repsBinding, prompt: previousRepsText, keyboard: .numberPad, width: 56)
                .focused(focusedField, equals: .reps(entry.persistentModelID))

        case .bodyweight:
            field("reps", text: repsBinding, prompt: previousRepsText, keyboard: .numberPad, width: 56)
                .focused(focusedField, equals: .reps(entry.persistentModelID))
            Text("+").foregroundStyle(.secondary)
            field("lb (opt.)", text: weightBinding, prompt: previousWeightText, keyboard: .decimalPad, width: 80)
                .focused(focusedField, equals: .weight(entry.persistentModelID))

        case .hold:
            field("sec", text: durationBinding, prompt: previousDurationText, keyboard: .numberPad, width: 64)
                .focused(focusedField, equals: .duration(entry.persistentModelID))
            Text("seconds").foregroundStyle(.secondary)
            Text("+").foregroundStyle(.secondary)
            field("lb (opt.)", text: weightBinding, prompt: previousWeightText, keyboard: .decimalPad, width: 80)
                .focused(focusedField, equals: .weight(entry.persistentModelID))

        case .erg, .cardio:
            EmptyView()
        }
    }

    private var previousWeightText: String? { previous?.weight.map { String(format: "%g", $0) } }
    private var previousRepsText: String? { previous?.reps.map(String.init) }
    private var previousDurationText: String? { previous?.duration.map { String(Int($0)) } }

    /// A text field with a large, easy-to-hit tap target — the default
    /// TextField's hit box is just its glyph bounds, which is too small to
    /// reliably tap mid-set.
    private func field(
        _ title: String,
        text: Binding<String>,
        prompt: String?,
        keyboard: UIKeyboardType,
        width: CGFloat
    ) -> some View {
        TextField(title, text: text, prompt: prompt.map { Text($0) })
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .frame(width: width, height: 44)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // String-backed bindings so an empty field maps cleanly to `nil`
    // instead of relying on optional-numeric TextField formatting.

    private var weightBinding: Binding<String> {
        Binding(
            get: { entry.weight.map { String(format: "%g", $0) } ?? "" },
            set: { entry.weight = Double($0) }
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
