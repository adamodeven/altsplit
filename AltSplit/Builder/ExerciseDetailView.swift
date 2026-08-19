import SwiftUI
import SwiftData

/// Shows where an exercise is used in the split and its logged history, so
/// you can tell at a glance whether it's actually earning its slot.
struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise

    @Query private var programs: [Program]
    @Query private var setEntries: [SetEntry]

    @State private var showingEditForm = false

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Type", value: exercise.type.displayName)
                if let group = exercise.muscleGroup {
                    LabeledContent("Muscle Group", value: group.displayName)
                }
                LabeledContent("Equipment", value: exercise.equipment.displayName)
                LabeledContent("Source", value: exercise.isUserCreated ? "Custom" : "Built-in")
            }

            Section("Used In") {
                if usages.isEmpty {
                    Text("Not currently scheduled in the split.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(usages, id: \.self) { usage in
                        Text(usage)
                    }
                }
            }

            Section("History") {
                if loggedEntries.isEmpty {
                    Text("No sets logged yet.")
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Sets logged", value: "\(loggedEntries.count)")
                    if let last = loggedEntries.first?.completedAt {
                        LabeledContent("Last performed", value: last.formatted(date: .abbreviated, time: .omitted))
                    }
                    if let best = bestSetDescription {
                        LabeledContent("Best set", value: best)
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditForm = true }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            ExerciseFormView(existing: exercise)
        }
    }

    private var usages: [String] {
        guard let program = programs.first else { return [] }
        var results: [String] = []
        for day in program.days.sorted(by: { $0.weekday < $1.weekday }) {
            for planned in day.poolA where planned.exercise?.persistentModelID == exercise.persistentModelID {
                results.append(usageLabel(day: day, phase: "Phase A", planned: planned))
            }
            for planned in day.poolB where planned.exercise?.persistentModelID == exercise.persistentModelID {
                results.append(usageLabel(day: day, phase: "Phase B", planned: planned))
            }
        }
        return results
    }

    private func usageLabel(day: DayTemplate, phase: String, planned: PlannedExercise) -> String {
        let base = "\(day.weekday.displayName) · \(phase)"
        return planned.modality == .standard ? base : "\(base) · \(planned.modality.displayName)"
    }

    private var loggedEntries: [SetEntry] {
        setEntries
            .filter { $0.exercise?.persistentModelID == exercise.persistentModelID && $0.isComplete }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Scoped to standard-modality sets — a tempo or eccentric set is
    /// deliberately lighter, so mixing it into "best set" would understate
    /// or misrepresent the exercise's real strength number.
    private var bestSetDescription: String? {
        let standardEntries = loggedEntries.filter { $0.modality == .standard }
        switch exercise.type {
        case .lift, .bodyweight:
            guard let best = standardEntries.max(by: { $0.volume < $1.volume }), best.volume > 0 else { return nil }
            if let weight = best.weight(in: .pounds), let reps = best.reps {
                return "\(weight.formatted()) \(UnitMass.pounds.symbol) × \(reps)"
            }
            return nil
        case .hold:
            guard let best = standardEntries.compactMap(\.duration).max() else { return nil }
            return "\(Int(best))s"
        case .erg, .cardio:
            return nil
        }
    }
}
