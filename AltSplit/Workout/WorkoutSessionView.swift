import SwiftUI
import SwiftData

/// Groups a planned exercise with the concrete sets logged against it this
/// session, in the day's original order.
private struct ExerciseLogGroup: Identifiable {
    let id: PersistentIdentifier
    let planned: PlannedExercise
    var entries: [SetEntry]
}

/// The active workout logger. Created fresh every time the workout box is
/// tapped — no intermediate confirm screen, straight into logging.
struct WorkoutSessionView: View {
    let day: ResolvedDay

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SetEntry.completedAt, order: .reverse) private var completedEntries: [SetEntry]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var recentSessions: [WorkoutSession]

    @State private var session: WorkoutSession?
    @State private var groups: [ExerciseLogGroup] = []
    @State private var startedAt = Date.now

    @State private var restRemaining: Int?
    @State private var restTotal: Int = 0
    @State private var restTask: Task<Void, Never>?
    /// The set whose checkmark started the active rest timer — unchecking
    /// this specific set should cancel that timer, but unchecking some
    /// other already-completed set shouldn't touch it.
    @State private var restSourceEntryID: PersistentIdentifier?

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
                if day.slotKind != .cardio {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(unit.symbol) { toggleUnit() }
                            .accessibilityLabel("Change weight unit")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { finish() }
                        .fontWeight(.semibold)
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
                Section {
                    ForEach(group.entries) { entry in
                        SetRowView(
                            entry: entry,
                            type: group.planned.exercise?.type ?? .lift,
                            unit: unit,
                            previous: previousEntry(for: group.planned.exercise, setIndex: entry.setIndex),
                            onComplete: { startRest(seconds: group.planned.restSeconds, sourceEntryID: entry.persistentModelID) },
                            onUncomplete: { cancelRestIfSource(entry.persistentModelID) },
                            focusedField: $focusedField
                        )
                    }
                    if let notes = group.planned.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    ExerciseGroupHeader(
                        title: group.planned.displayTitle,
                        canRemoveSet: group.entries.count > 1,
                        onAddSet: { addSet(to: group.id) },
                        onRemoveSet: { removeSet(from: group.id) }
                    )
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

    // MARK: - Units

    /// Falls back to pounds only once no prior session exists to read a
    /// preference from — kept off of Settings deliberately (see DESIGN.md)
    /// so a session reviewed later always reads back as it was entered.
    private var unit: UnitMass { session?.preferredUnit ?? recentSessions.first?.preferredUnit ?? .pounds }

    private func toggleUnit() {
        session?.preferredUnit = unit == .pounds ? .kilograms : .pounds
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
            startedAt: .now,
            preferredUnit: recentSessions.first?.preferredUnit ?? .pounds
        )
        modelContext.insert(newSession)
        startedAt = newSession.startedAt ?? .now

        if day.slotKind != .cardio {
            var built: [ExerciseLogGroup] = []
            for planned in day.exercises {
                var entries: [SetEntry] = []
                for index in 0..<max(planned.targetSets, 1) {
                    let entry = SetEntry(exercise: planned.exercise, setIndex: index, modality: planned.modality)
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

    // MARK: - Live set count

    private func addSet(to groupID: PersistentIdentifier) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let group = groups[index]
        let entry = SetEntry(exercise: group.planned.exercise, setIndex: group.entries.count, modality: group.planned.modality)
        modelContext.insert(entry)
        session?.entries.append(entry)
        groups[index].entries.append(entry)
    }

    private func removeSet(from groupID: PersistentIdentifier) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        guard groups[index].entries.count > 1, let last = groups[index].entries.last else { return }
        cancelRestIfSource(last.persistentModelID)
        groups[index].entries.removeLast()
        session?.entries.removeAll { $0.persistentModelID == last.persistentModelID }
        modelContext.delete(last)
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

    // MARK: - Rest timer

    private func startRest(seconds: Int, sourceEntryID: PersistentIdentifier) {
        restTask?.cancel()
        restSourceEntryID = sourceEntryID
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
        restSourceEntryID = nil
    }

    /// Called when a set is unchecked — only cancels the timer if that set
    /// is the one that started it, so unchecking an older, unrelated set
    /// doesn't kill the timer for the one in progress.
    private func cancelRestIfSource(_ entryID: PersistentIdentifier) {
        guard restSourceEntryID == entryID else { return }
        skipRest()
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

/// Section header for a logged exercise, with inline +/- controls so the
/// number of sets can be adjusted live as the workout is performed instead
/// of only ever matching the planned target.
private struct ExerciseGroupHeader: View {
    let title: String
    let canRemoveSet: Bool
    let onAddSet: () -> Void
    let onRemoveSet: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Spacer()
            Button(action: onRemoveSet) {
                Image(systemName: "minus.circle")
            }
            .disabled(!canRemoveSet)
            .accessibilityLabel("Remove set")

            Button(action: onAddSet) {
                Image(systemName: "plus.circle")
            }
            .accessibilityLabel("Add set")
        }
        .buttonStyle(.plain)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .imageScale(.medium)
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
