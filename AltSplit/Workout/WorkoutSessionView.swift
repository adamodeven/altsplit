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

    @Query(sort: \SetEntry.completedAt, order: .reverse) private var completedEntries: [SetEntry]

    @State private var session: WorkoutSession?
    @State private var groups: [ExerciseLogGroup] = []
    @State private var startedAt = Date.now

    @State private var restRemaining: Int?
    @State private var restTotal: Int = 0
    @State private var restTask: Task<Void, Never>?

    @FocusState private var focusedField: SetField?

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
                ToolbarItem(placement: .principal) {
                    ElapsedTimeLabel(start: startedAt)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { finish() }
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Next") { advanceFocus() }
                        .disabled(!hasNextField)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let restRemaining {
                    RestTimerBanner(remaining: restRemaining, total: restTotal, onSkip: skipRest)
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
                            type: group.planned.exercise?.type ?? .lift,
                            previous: previousEntry(for: group.planned.exercise, setIndex: entry.setIndex),
                            onComplete: { startRest(seconds: group.planned.restSeconds) },
                            focusedField: $focusedField
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
        startedAt = newSession.startedAt ?? .now

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
        Task { await AccountabilityCoordinator.refreshBadge(context: modelContext) }
        dismiss()
    }

    /// Cascade delete rules on `WorkoutSession` take the entries and any
    /// cardio result with it — an abandoned session leaves nothing behind.
    private func discardAndDismiss() {
        restTask?.cancel()
        if let session {
            modelContext.delete(session)
        }
        dismiss()
    }

    // MARK: - Previous performance

    /// Last time this exercise was logged, preferring the same set index so
    /// "set 2" suggests what set 2 was last time rather than set 1's number.
    /// Excludes sets from this in-progress session.
    private func previousEntry(for exercise: Exercise?, setIndex: Int) -> SetEntry? {
        guard let exercise else { return nil }
        let currentIDs = Set(groups.flatMap(\.entries).map(\.persistentModelID))
        let candidates = completedEntries.filter {
            $0.exercise?.persistentModelID == exercise.persistentModelID
                && !currentIDs.contains($0.persistentModelID)
        }
        return candidates.first { $0.setIndex == setIndex } ?? candidates.first
    }

    // MARK: - Keyboard focus

    private var orderedFields: [SetField] {
        groups.flatMap { group -> [SetField] in
            let type = group.planned.exercise?.type ?? .lift
            return group.entries.flatMap { entry -> [SetField] in
                switch type {
                case .lift: [.weight(entry.persistentModelID), .reps(entry.persistentModelID)]
                case .bodyweight: [.reps(entry.persistentModelID), .weight(entry.persistentModelID)]
                case .hold: [.duration(entry.persistentModelID), .weight(entry.persistentModelID)]
                case .erg, .cardio: []
                }
            }
        }
    }

    private var hasNextField: Bool {
        guard let focusedField, let index = orderedFields.firstIndex(of: focusedField) else { return false }
        return index + 1 < orderedFields.count
    }

    private func advanceFocus() {
        guard let focusedField, let index = orderedFields.firstIndex(of: focusedField) else { return }
        let nextIndex = index + 1
        self.focusedField = nextIndex < orderedFields.count ? orderedFields[nextIndex] : nil
    }

    // MARK: - Rest timer

    private func startRest(seconds: Int) {
        restTask?.cancel()
        guard seconds > 0 else {
            restRemaining = nil
            return
        }
        restTotal = seconds
        restRemaining = seconds
        restTask = Task {
            while true {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard let remaining = restRemaining, remaining > 1 else {
                    restRemaining = nil
                    return
                }
                restRemaining = remaining - 1
            }
        }
    }

    private func skipRest() {
        restTask?.cancel()
        restRemaining = nil
    }
}

/// Live-updating elapsed time since the session started, shown in the
/// navigation bar so there's always a clock running during the workout.
private struct ElapsedTimeLabel: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            Text(formatted(context.date.timeIntervalSince(start)))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Countdown shown after a set is checked off, so the next set starts on
/// time without having to eyeball a phone clock between sets.
private struct RestTimerBanner: View {
    let remaining: Int
    let total: Int
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)
            Text("Rest · \(remaining)s")
                .font(.headline.monospacedDigit())
            ProgressView(value: Double(total - remaining), total: Double(max(total, 1)))
                .frame(maxWidth: 80)
            Spacer()
            Button("Skip", action: onSkip)
                .buttonStyle(.bordered)
        }
        .padding()
        .glassEffect(Glass.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
