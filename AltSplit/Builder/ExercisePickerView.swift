import SwiftUI
import SwiftData

/// Sheet for adding an exercise from the library to a day's pool.
struct ExercisePickerView: View {
    let onSelect: (Exercise) -> Void

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List(filtered, id: \.persistentModelID) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .foregroundStyle(.primary)
                        Text(subtitle(for: exercise))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func subtitle(for exercise: Exercise) -> String {
        [exercise.muscleGroup?.displayName, exercise.type.displayName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
