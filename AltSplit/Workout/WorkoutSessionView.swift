import SwiftUI
import SwiftData

/// Groups a planned exercise with the concrete sets logged against it this
/// session, in the day's original order.
private struct ExerciseLogGroup: Identifiable {
    let id: PersistentIdentifier
    let planned: PlannedExercise
    let entries: [SetEntry]
}

/// The active workout logger. Created fresh every time the workout box is
/// tapped — no intermediate confirm screen, straight into logging.
struct WorkoutSessionView: View {
    let day: ResolvedDay

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var session: WorkoutSession?
    @State private var groups: [ExerciseLogGroup] = []

    @State private var cardioDistance = ""
    @State private var cardioMinutes = ""
    @State private var cardioSeconds = ""
    @State private var cardioStrokeRate = ""

    var body: some View {
        NavigationStack {
            Group {
                if day.slotKind == .cardio {
                    cardioForm
                } else {
                    liftForm
                }
            }
            .navigationTitle(day.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { discardAndDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { finish() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task { ensureSessionExists() }
    }

    private var liftForm: some View {
        List {
            ForEach(groups) { group in
                Section(group.planned.exercise?.name ?? "—") {
                    ForEach(group.entries) { entry in
                        SetRowView(
                            entry: entry,
                            type: group.planned.exercise?.type ?? .lift
                        )
                    }
                    if let notes = group.planned.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var cardioForm: some View {
        Form {
            if let planned = day.exercises.first {
                Section("Target") {
                    LabeledContent(planned.exercise?.name ?? "Erg", value: planned.targetSummary)
                }
            }
            Section("Result") {
                TextField("Distance (meters)", text: $cardioDistance)
                    .keyboardType(.numberPad)
                HStack {
                    TextField("Minutes", text: $cardioMinutes)
                        .keyboardType(.numberPad)
                    Text(":")
                        .foregroundStyle(.secondary)
                    TextField("Seconds", text: $cardioSeconds)
                        .keyboardType(.numberPad)
                }
                TextField("Stroke rate (optional)", text: $cardioStrokeRate)
                    .keyboardType(.numberPad)
            }
        }
    }

    // MARK: - Session lifecycle

    private func ensureSessionExists() {
        guard session == nil else { return }

        let newSession = WorkoutSession(
            date: day.date,
            phase: day.phase,
            weekday: day.weekday,
            status: .partial,
            focusGroup: day.focusGroup,
            startedAt: .now
        )
        modelContext.insert(newSession)

        if day.slotKind != .cardio {
            var built: [ExerciseLogGroup] = []
            for planned in day.exercises {
                var entries: [SetEntry] = []
                for index in 0..<max(planned.targetSets, 1) {
                    let entry = SetEntry(exercise: planned.exercise, setIndex: index)
                    modelContext.insert(entry)
                    newSession.entries.append(entry)
                    entries.append(entry)
                }
                built.append(ExerciseLogGroup(id: planned.persistentModelID, planned: planned, entries: entries))
            }
            groups = built
        }

        session = newSession
    }

    private func finish() {
        guard let session else { dismiss(); return }

        if day.slotKind == .cardio {
            let distance = Int(cardioDistance) ?? 0
            let duration = TimeInterval((Int(cardioMinutes) ?? 0) * 60 + (Int(cardioSeconds) ?? 0))
            if distance > 0, duration > 0 {
                let result = CardioResult(
                    distanceMeters: distance,
                    duration: duration,
                    avgStrokeRate: Int(cardioStrokeRate)
                )
                modelContext.insert(result)
                session.cardioResult = result
                session.status = .completed
            }
        } else {
            let totalSets = groups.reduce(0) { $0 + $1.entries.count }
            let completedSets = groups.reduce(0) { $0 + $1.entries.filter(\.isComplete).count }
            session.status = completedSets == totalSets && totalSets > 0 ? .completed : .partial
        }

        session.endedAt = .now
        try? modelContext.save()
        dismiss()
    }

    /// Cascade delete rules on `WorkoutSession` take the entries and any
    /// cardio result with it — an abandoned session leaves nothing behind.
    private func discardAndDismiss() {
        if let session {
            modelContext.delete(session)
        }
        dismiss()
    }
}
