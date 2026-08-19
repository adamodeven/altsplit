import SwiftUI

/// Edits targets for one exercise within a day's pool. Which fields show
/// depends on the exercise's type, same rule as the logger itself.
struct PlannedExerciseEditorView: View {
    @Bindable var planned: PlannedExercise
    @Environment(\.dismiss) private var dismiss

    @State private var repLow: Int
    @State private var repHigh: Int
    @State private var durationSeconds: Int
    @State private var distanceMeters: Int

    init(planned: PlannedExercise) {
        self.planned = planned
        _repLow = State(initialValue: planned.targetRepRange?.lowerBound ?? 8)
        _repHigh = State(initialValue: planned.targetRepRange?.upperBound ?? 12)
        _durationSeconds = State(initialValue: Int(planned.targetDuration ?? 30))
        _distanceMeters = State(initialValue: planned.targetDistanceMeters ?? 2000)
    }

    private var type: ExerciseType { planned.exercise?.type ?? .lift }

    var body: some View {
        NavigationStack {
            Form {
                Section(planned.exercise?.name ?? "Exercise") {
                    Picker("Modality", selection: $planned.modality) {
                        ForEach(Modality.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }

                    Stepper("Sets: \(planned.targetSets)", value: $planned.targetSets, in: 1...10)

                    switch type {
                    case .lift, .bodyweight:
                        Stepper("Reps low: \(repLow)", value: $repLow, in: 1...30)
                        Stepper("Reps high: \(repHigh)", value: $repHigh, in: repLow...30)
                    case .hold:
                        Stepper("Duration: \(durationSeconds)s", value: $durationSeconds, in: 5...600, step: 5)
                    case .erg, .cardio:
                        Stepper("Distance: \(distanceMeters)m", value: $distanceMeters, in: 250...20000, step: 250)
                    }

                    Stepper("Rest: \(planned.restSeconds)s", value: $planned.restSeconds, in: 0...300, step: 15)
                }

                Section("Notes") {
                    TextField("Optional", text: notesBinding, axis: .vertical)
                }
            }
            .navigationTitle("Edit Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var notesBinding: Binding<String> {
        Binding(get: { planned.notes ?? "" }, set: { planned.notes = $0.isEmpty ? nil : $0 })
    }

    private func applyAndDismiss() {
        switch type {
        case .lift, .bodyweight:
            planned.targetRepLow = repLow
            planned.targetRepHigh = repHigh
        case .hold:
            planned.targetDuration = TimeInterval(durationSeconds)
        case .erg, .cardio:
            planned.targetDistanceMeters = distanceMeters
        }
        dismiss()
    }
}
