import SwiftUI
import SwiftData

struct DayEditorView: View {
    @Bindable var day: DayTemplate
    @Environment(\.modelContext) private var modelContext

    @State private var showingExercisePicker = false
    @State private var addTargetPhase: Phase = .a
    @State private var editingPlanned: PlannedExercise?

    var body: some View {
        List {
            Section("Day") {
                Picker("Session Type", selection: $day.slotKind) {
                    ForEach(SlotKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                NavigationLink {
                    MuscleGroupPickerView(selection: $day.groups)
                } label: {
                    LabeledContent("Groups", value: groupsSummary)
                }
            }

            poolSection(title: "Phase A", phase: .a, pool: day.poolA)
            poolSection(title: "Phase B", phase: .b, pool: day.poolB)
        }
        .navigationTitle(day.weekday.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { exercise in
                addExercise(exercise, to: addTargetPhase)
            }
        }
        .sheet(item: $editingPlanned) { planned in
            PlannedExerciseEditorView(planned: planned)
        }
    }

    private var groupsSummary: String {
        day.groups.isEmpty ? "None" : day.groups.map(\.displayName).joined(separator: ", ")
    }

    @ViewBuilder
    private func poolSection(title: String, phase: Phase, pool: [PlannedExercise]) -> some View {
        Section(title) {
            ForEach(pool.sorted { $0.order < $1.order }, id: \.persistentModelID) { planned in
                Button {
                    editingPlanned = planned
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(planned.exercise?.name ?? "—")
                                .foregroundStyle(.primary)
                            Text(planned.targetSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .onDelete { offsets in delete(offsets, phase: phase) }
            .onMove { source, destination in move(from: source, to: destination, phase: phase) }

            Button {
                addTargetPhase = phase
                showingExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
            }
        }
    }

    private func addExercise(_ exercise: Exercise, to phase: Phase) {
        let pool = phase == .a ? day.poolA : day.poolB
        let nextOrder = (pool.map(\.order).max() ?? -1) + 1
        let planned = PlannedExercise(exercise: exercise, order: nextOrder)
        modelContext.insert(planned)
        if phase == .a {
            day.poolA.append(planned)
        } else {
            day.poolB.append(planned)
        }
        try? modelContext.save()
    }

    private func delete(_ offsets: IndexSet, phase: Phase) {
        let sorted = (phase == .a ? day.poolA : day.poolB).sorted { $0.order < $1.order }
        let idsToDelete = Set(offsets.map { sorted[$0].persistentModelID })

        if phase == .a {
            day.poolA.removeAll { idsToDelete.contains($0.persistentModelID) }
        } else {
            day.poolB.removeAll { idsToDelete.contains($0.persistentModelID) }
        }
        for planned in sorted where idsToDelete.contains(planned.persistentModelID) {
            modelContext.delete(planned)
        }
        try? modelContext.save()
    }

    private func move(from source: IndexSet, to destination: Int, phase: Phase) {
        var sorted = (phase == .a ? day.poolA : day.poolB).sorted { $0.order < $1.order }
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, planned) in sorted.enumerated() {
            planned.order = index
        }
        try? modelContext.save()
    }
}
