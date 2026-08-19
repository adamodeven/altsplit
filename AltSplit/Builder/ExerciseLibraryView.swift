import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var groupFilter: MuscleGroup?
    @State private var typeFilter: ExerciseType?
    @State private var showingAddExercise = false

    var body: some View {
        List {
            ForEach(filtered, id: \.persistentModelID) { exercise in
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                            Text(subtitle(for: exercise))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !exercise.isUserCreated {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Exercise Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExercise = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addExerciseButton")
            }
            ToolbarItem(placement: .primaryAction) {
                filterMenu
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            ExerciseFormView(existing: nil)
        }
    }

    private var filterMenu: some View {
        Menu {
            Menu("Muscle Group") {
                Button("All") { groupFilter = nil }
                ForEach(MuscleGroup.allCases) { group in
                    Button(group.displayName) { groupFilter = group }
                }
            }
            Menu("Type") {
                Button("All") { typeFilter = nil }
                ForEach(ExerciseType.allCases, id: \.self) { type in
                    Button(type.displayName) { typeFilter = type }
                }
            }
            if groupFilter != nil || typeFilter != nil {
                Button("Clear Filters", role: .destructive) {
                    groupFilter = nil
                    typeFilter = nil
                }
            }
        } label: {
            Image(systemName: groupFilter != nil || typeFilter != nil
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .accessibilityIdentifier("filterMenuButton")
    }

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            (searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText))
                && (groupFilter == nil || exercise.muscleGroup == groupFilter)
                && (typeFilter == nil || exercise.type == typeFilter)
        }
    }

    private func subtitle(for exercise: Exercise) -> String {
        [exercise.muscleGroup?.displayName, exercise.type.displayName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
