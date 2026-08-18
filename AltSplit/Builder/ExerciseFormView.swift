import SwiftUI
import SwiftData

/// Add or edit an exercise. New exercises are flagged `isUserCreated` so a
/// future library refresh can't clobber them; editing a seeded exercise
/// leaves that flag untouched.
struct ExerciseFormView: View {
    /// nil means "creating a new exercise".
    let existing: Exercise?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var type: ExerciseType
    @State private var modality: Modality
    @State private var muscleGroup: MuscleGroup?
    @State private var equipment: Equipment

    init(existing: Exercise?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _type = State(initialValue: existing?.type ?? .lift)
        _modality = State(initialValue: existing?.modality ?? .standard)
        _muscleGroup = State(initialValue: existing?.muscleGroup)
        _equipment = State(initialValue: existing?.equipment ?? .other)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("exerciseNameField")
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(ExerciseType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Modality", selection: $modality) {
                        ForEach(Modality.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }

                if type != .erg && type != .cardio {
                    Section("Muscle Group") {
                        Picker("Muscle Group", selection: $muscleGroup) {
                            Text("None").tag(MuscleGroup?.none)
                            ForEach(MuscleGroup.allCases) { group in
                                Text(group.displayName).tag(MuscleGroup?.some(group))
                            }
                        }
                    }
                }

                Section("Equipment") {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("saveExerciseButton")
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing {
            existing.name = trimmedName
            existing.type = type
            existing.modality = modality
            existing.muscleGroup = type == .erg || type == .cardio ? nil : muscleGroup
            existing.equipment = equipment
        } else {
            let exercise = Exercise(
                name: trimmedName,
                type: type,
                modality: modality,
                muscleGroup: type == .erg || type == .cardio ? nil : muscleGroup,
                equipment: equipment,
                isUserCreated: true
            )
            modelContext.insert(exercise)
        }
        try? modelContext.save()
        dismiss()
    }
}
