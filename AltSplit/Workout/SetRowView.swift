import SwiftUI

/// One set of one exercise. Which fields show depends on `type` — the same
/// rule DESIGN.md sets for the typing model: type drives the logging UI.
struct SetRowView: View {
    @Bindable var entry: SetEntry
    let type: ExerciseType

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(entry.setIndex + 1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            fields

            Spacer()

            Button {
                entry.completedAt = entry.isComplete ? nil : .now
            } label: {
                Image(systemName: entry.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(entry.isComplete ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("setCheckmark")
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch type {
        case .lift:
            TextField("lb", text: weightBinding)
                .keyboardType(.decimalPad)
                .frame(width: 64)
            Text("×").foregroundStyle(.secondary)
            TextField("reps", text: repsBinding)
                .keyboardType(.numberPad)
                .frame(width: 48)

        case .bodyweight:
            TextField("reps", text: repsBinding)
                .keyboardType(.numberPad)
                .frame(width: 48)
            Text("+").foregroundStyle(.secondary)
            TextField("lb (opt.)", text: weightBinding)
                .keyboardType(.decimalPad)
                .frame(width: 72)

        case .hold:
            TextField("sec", text: durationBinding)
                .keyboardType(.numberPad)
                .frame(width: 56)
            Text("seconds").foregroundStyle(.secondary)
            Text("+").foregroundStyle(.secondary)
            TextField("lb (opt.)", text: weightBinding)
                .keyboardType(.decimalPad)
                .frame(width: 72)

        case .erg, .cardio:
            EmptyView()
        }
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
