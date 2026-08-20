import SwiftUI
import SwiftData

/// Which cardio result field currently has focus — used only to fire the
/// tiny selection haptic when entering a field, same as the lift form.
private enum CardioField: Hashable {
    case distance, minutes, seconds, strokeRate
}

/// The active workout logger. Created fresh every time the workout box is
/// tapped or the minimized workout is reopened — all persistent-across-
/// dismissal state (logged sets, rest timer, elapsed time) lives on `state`,
/// not here, so tapping Minimize just hides this view without losing any of
/// it. Created fresh means no intermediate confirm screen either — straight
/// into logging.
struct WorkoutSessionView: View {
    let day: ResolvedDay
    @Bindable var state: ActiveWorkoutState
    /// Hides this screen without ending the workout — the session, sets, and
    /// rest timer all keep going on `state`.
    var onMinimize: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SetEntry.completedAt, order: .reverse) private var completedEntries: [SetEntry]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var recentSessions: [WorkoutSession]

    @FocusState private var focusedField: SetField?
    @FocusState private var focusedCardioField: CardioField?

    @State private var scrollProxy: ScrollViewProxy?

    @State private var invalidEntryID: PersistentIdentifier?
    @State private var shakeToken = 0
    @State private var validationHapticToken = 0
    @State private var showingCancelConfirmation = false

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
                    Button("Cancel") {
                        if hasLoggedAnything {
                            showingCancelConfirmation = true
                        } else {
                            discardAndDismiss()
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    ElapsedTimeLabel(start: state.startedAt)
                }
                if day.slotKind != .cardio {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(unit.symbol) { toggleUnit() }
                            .accessibilityLabel("Change weight unit")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if canFinishDirectly {
                        Button("Finish") { finish() }
                            .fontWeight(.semibold)
                    } else {
                        Button(action: onMinimize) {
                            Label("Minimize", systemImage: "chevron.down")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let restRemaining = state.restRemaining {
                    RestTimerBanner(remaining: restRemaining, total: state.restTotal, onSkip: state.skipRest)
                }
            }
            .confirmationDialog("End this workout?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
                Button("Save & End Workout") { finish(force: true) }
                Button("Discard Workout", role: .destructive) { discardAndDismiss() }
                Button("Keep Going", role: .cancel) {}
            }
        }
        .sensoryFeedback(.error, trigger: validationHapticToken)
        .sensoryFeedback(.selection, trigger: focusedField) { _, new in new != nil }
        .sensoryFeedback(.selection, trigger: focusedCardioField) { _, new in new != nil }
        .task { ensureSessionExists() }
    }

    /// Cardio days have nothing to "check off," so Finish is always live.
    /// Lift/bodyweight/hold days swap in the Minimize button until every
    /// logged set is checked, matching the request that Finish only takes
    /// over once there's nothing left to fill in.
    private var canFinishDirectly: Bool {
        day.slotKind == .cardio || state.allSetsComplete
    }

    /// Whether Cancel should ask before discarding — nothing to confirm if
    /// nothing's been touched yet.
    private var hasLoggedAnything: Bool {
        if day.slotKind == .cardio {
            return !state.cardioDistance.isEmpty || !state.cardioMinutes.isEmpty || !state.cardioSeconds.isEmpty
        }
        return state.groups.flatMap(\.entries).contains {
            $0.isComplete || $0.weightKilograms != nil || $0.reps != nil || $0.duration != nil
        }
    }

    private var liftForm: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(state.groups) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            SetRowView(
                                entry: entry,
                                type: group.planned.exercise?.type ?? .lift,
                                unit: unit,
                                previous: previousEntry(for: group.planned.exercise, setIndex: entry.setIndex),
                                onComplete: { state.startRest(seconds: group.planned.restSeconds, sourceEntryID: entry.persistentModelID) },
                                onUncomplete: { state.cancelRestIfSource(entry.persistentModelID) },
                                focusedField: $focusedField,
                                shakeTrigger: entry.persistentModelID == invalidEntryID ? shakeToken : 0
                            )
                            .id(entry.persistentModelID)
                            .swipeActions(edge: .trailing) {
                                if group.entries.count > 1 {
                                    Button(role: .destructive) {
                                        deleteSet(groupID: group.id, entryID: entry.persistentModelID)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
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
            .scrollDismissesKeyboard(.interactively)
            .sensoryFeedback(.selection, trigger: state.groups.map(\.entries.count))
            .onAppear { scrollProxy = proxy }
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
                TextField("Distance (meters)", text: $state.cardioDistance)
                    .keyboardType(.numberPad)
                    .focused($focusedCardioField, equals: .distance)
                HStack {
                    TextField("Minutes", text: $state.cardioMinutes)
                        .keyboardType(.numberPad)
                        .focused($focusedCardioField, equals: .minutes)
                    Text(":")
                        .foregroundStyle(.secondary)
                    TextField("Seconds", text: $state.cardioSeconds)
                        .keyboardType(.numberPad)
                        .focused($focusedCardioField, equals: .seconds)
                }
                TextField("Stroke rate (optional)", text: $state.cardioStrokeRate)
                    .keyboardType(.numberPad)
                    .focused($focusedCardioField, equals: .strokeRate)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Units

    /// Falls back to pounds only once no prior session exists to read a
    /// preference from — kept off of Settings deliberately (see DESIGN.md)
    /// so a session reviewed later always reads back as it was entered.
    private var unit: UnitMass { state.session?.preferredUnit ?? recentSessions.first?.preferredUnit ?? .pounds }

    private func toggleUnit() {
        state.session?.preferredUnit = unit == .pounds ? .kilograms : .pounds
    }

    // MARK: - Session lifecycle

    private func ensureSessionExists() {
        if let existing = state.session {
            if Calendar.current.isDate(existing.date, inSameDayAs: day.date) {
                return
            }
            // A minimized session lingered past midnight — it belongs to a
            // day that's no longer "today," so it can't be resumed here.
            modelContext.delete(existing)
            state.reset()
        }

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
        state.startedAt = newSession.startedAt ?? .now

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
            state.groups = built
        }

        state.session = newSession
    }

    private func finish(force: Bool = false) {
        guard let session = state.session else { dismiss(); return }

        if day.slotKind == .cardio {
            let distance = Int(state.cardioDistance) ?? 0
            let duration = TimeInterval((Int(state.cardioMinutes) ?? 0) * 60 + (Int(state.cardioSeconds) ?? 0))
            if distance > 0, duration > 0 {
                let result = CardioResult(
                    distanceMeters: distance,
                    duration: duration,
                    avgStrokeRate: Int(state.cardioStrokeRate)
                )
                modelContext.insert(result)
                session.cardioResult = result
                session.status = .completed
            }
        } else {
            if !force, let badEntry = firstInvalidEntry() {
                revealValidationIssue(for: badEntry)
                return
            }
            let totalSets = state.groups.reduce(0) { $0 + $1.entries.count }
            let completedSets = state.groups.reduce(0) { $0 + $1.entries.filter(\.isComplete).count }
            session.status = completedSets == totalSets && totalSets > 0 ? .completed : .partial
        }

        session.endedAt = .now
        try? modelContext.save()
        Task { await AccountabilityCoordinator.refreshBadge(context: modelContext) }
        state.reset()
        dismiss()
    }

    /// Cascade delete rules on `WorkoutSession` take the entries and any
    /// cardio result with it — an abandoned session leaves nothing behind.
    private func discardAndDismiss() {
        if let session = state.session {
            modelContext.delete(session)
        }
        state.reset()
        dismiss()
    }

    // MARK: - Finish validation

    /// A set that's checked off but missing a value its exercise type
    /// requires — e.g. checked with no weight/rep logged. Only checked sets
    /// are validated; an unchecked set is just an unperformed set.
    private func firstInvalidEntry() -> SetEntry? {
        for group in state.groups {
            let type = group.planned.exercise?.type ?? .lift
            for entry in group.entries where entry.isComplete && !isValid(entry, type: type) {
                return entry
            }
        }
        return nil
    }

    private func isValid(_ entry: SetEntry, type: ExerciseType) -> Bool {
        switch type {
        case .lift: entry.weightKilograms != nil && entry.reps != nil
        case .bodyweight: entry.reps != nil
        case .hold: entry.duration != nil
        case .erg, .cardio: true
        }
    }

    private func revealValidationIssue(for entry: SetEntry) {
        invalidEntryID = entry.persistentModelID
        withAnimation {
            scrollProxy?.scrollTo(entry.persistentModelID, anchor: .center)
        }
        shakeToken += 1
        validationHapticToken += 1
    }

    // MARK: - Live set count

    private func addSet(to groupID: PersistentIdentifier) {
        guard let index = state.groups.firstIndex(where: { $0.id == groupID }) else { return }
        let group = state.groups[index]
        let entry = SetEntry(exercise: group.planned.exercise, setIndex: group.entries.count, modality: group.planned.modality)
        modelContext.insert(entry)
        state.session?.entries.append(entry)
        state.groups[index].entries.append(entry)
    }

    private func removeSet(from groupID: PersistentIdentifier) {
        guard let index = state.groups.firstIndex(where: { $0.id == groupID }) else { return }
        guard state.groups[index].entries.count > 1, let last = state.groups[index].entries.last else { return }
        state.cancelRestIfSource(last.persistentModelID)
        state.groups[index].entries.removeLast()
        state.session?.entries.removeAll { $0.persistentModelID == last.persistentModelID }
        modelContext.delete(last)
    }

    private func deleteSet(groupID: PersistentIdentifier, entryID: PersistentIdentifier) {
        guard let index = state.groups.firstIndex(where: { $0.id == groupID }) else { return }
        guard state.groups[index].entries.count > 1 else { return }
        guard let entryIndex = state.groups[index].entries.firstIndex(where: { $0.persistentModelID == entryID }) else { return }
        let entry = state.groups[index].entries[entryIndex]
        state.cancelRestIfSource(entryID)
        state.groups[index].entries.remove(at: entryIndex)
        for (position, remaining) in state.groups[index].entries.enumerated() {
            remaining.setIndex = position
        }
        state.session?.entries.removeAll { $0.persistentModelID == entryID }
        modelContext.delete(entry)
    }

    // MARK: - Previous performance

    /// Last time this exercise was logged, preferring the same set index so
    /// "set 2" suggests what set 2 was last time rather than set 1's number.
    /// Excludes sets from this in-progress session.
    private func previousEntry(for exercise: Exercise?, setIndex: Int) -> SetEntry? {
        guard let exercise else { return nil }
        let currentIDs = Set(state.groups.flatMap(\.entries).map(\.persistentModelID))
        let candidates = completedEntries.filter {
            $0.exercise?.persistentModelID == exercise.persistentModelID
                && !currentIDs.contains($0.persistentModelID)
        }
        return candidates.first { $0.setIndex == setIndex } ?? candidates.first
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
