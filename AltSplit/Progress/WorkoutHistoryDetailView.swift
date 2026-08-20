import SwiftUI
import SwiftData

/// Read-only playback of one finished session — whatever was actually
/// logged, grouped the same way the live logger grouped it.
struct WorkoutHistoryDetailView: View {
    let session: WorkoutSession

    var body: some View {
        Group {
            if let cardioResult = session.cardioResult {
                cardioSummary(cardioResult)
            } else {
                liftSummary
            }
        }
        .navigationTitle(SessionSummary.title(for: session))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(session.phase.displayName) · \(session.weekday.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(session.date.formatted(date: .complete, time: .omitted))
                Spacer()
                Text(session.status.displayName)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if let duration = session.duration {
                Text(SessionSummary.formattedDuration(duration))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Lift / bodyweight / hold days

    private var liftSummary: some View {
        List {
            Section { header }
                .listRowSeparator(.hidden)

            ForEach(exerciseGroups) { group in
                Section(group.title) {
                    ForEach(group.entries, id: \.persistentModelID) { entry in
                        HStack {
                            Text("Set \(entry.setIndex + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .leading)
                            if entry.isWarmup {
                                Text("Warmup")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.fill.tertiary, in: Capsule())
                            }
                            Spacer()
                            Text(summary(for: entry, type: group.type))
                                .foregroundStyle(entry.isComplete ? .primary : .secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }

            if let notes = session.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func summary(for entry: SetEntry, type: ExerciseType) -> String {
        guard entry.isComplete else { return "Not logged" }
        let unit = session.preferredUnit
        switch type {
        case .lift:
            let weight = entry.weight(in: unit).map { String(format: "%g", $0) } ?? "—"
            let reps = entry.reps.map(String.init) ?? "—"
            return "\(weight) \(unit.symbol) × \(reps)"
        case .bodyweight:
            let reps = entry.reps.map { "\($0) reps" } ?? "—"
            guard let weight = entry.weight(in: unit) else { return reps }
            return "\(reps) + \(String(format: "%g", weight)) \(unit.symbol)"
        case .hold:
            let duration = entry.duration.map { "\(Int($0))s" } ?? "—"
            guard let weight = entry.weight(in: unit) else { return duration }
            return "\(duration) + \(String(format: "%g", weight)) \(unit.symbol)"
        case .erg, .cardio:
            return "—"
        }
    }

    /// Groups entries by exercise + modality, preserving first-appearance
    /// order (the order they were logged in), with each group's sets in
    /// `setIndex` order.
    private var exerciseGroups: [ExerciseGroup] {
        var order: [String] = []
        var byKey: [String: ExerciseGroup] = [:]

        for entry in session.entries {
            let key = "\(entry.exercise?.persistentModelID.hashValue ?? 0)-\(entry.modalityRaw)"
            if byKey[key] == nil {
                order.append(key)
                byKey[key] = ExerciseGroup(
                    id: key,
                    title: entry.exercise?.displayTitle(modality: entry.modality) ?? "—",
                    type: entry.exercise?.type ?? .lift,
                    entries: []
                )
            }
            byKey[key]?.entries.append(entry)
        }

        return order.compactMap { byKey[$0] }.map { group in
            var group = group
            group.entries.sort { $0.setIndex < $1.setIndex }
            return group
        }
    }

    private struct ExerciseGroup: Identifiable {
        let id: String
        let title: String
        let type: ExerciseType
        var entries: [SetEntry]
    }

    // MARK: - Cardio days

    private func cardioSummary(_ result: CardioResult) -> some View {
        List {
            Section { header }
                .listRowSeparator(.hidden)

            Section("Result") {
                LabeledContent("Distance", value: "\(result.distanceMeters) m")
                LabeledContent("Time", value: SessionSummary.formattedDuration(result.duration))
                LabeledContent("Avg. Split", value: "\(result.formattedSplit) /500m")
                if let strokeRate = result.avgStrokeRate {
                    LabeledContent("Stroke Rate", value: "\(strokeRate) spm")
                }
                if let heartRate = result.avgHeartRate {
                    LabeledContent("Heart Rate", value: "\(heartRate) bpm")
                }
            }

            if let notes = session.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private extension Exercise {
    /// Mirrors `PlannedExercise.displayTitle`, but for a logged exercise
    /// where only the `Exercise` and the modality it was logged under (from
    /// `SetEntry`) are available — there's no `PlannedExercise` in history.
    func displayTitle(modality: Modality) -> String {
        modality == .standard ? name : "\(name) · \(modality.displayName)"
    }
}
