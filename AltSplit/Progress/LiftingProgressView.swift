import SwiftUI
import SwiftData
import Charts

struct LiftingProgressView: View {
    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var programs: [Program]

    @State private var selectedExercise: Exercise?
    @State private var selectedGroup: MuscleGroup = .chest

    var body: some View {
        ScrollView {
            if sessions.allSatisfy({ $0.entries.allSatisfy { !$0.isComplete } }) {
                ContentUnavailableView(
                    "No Lifting History Yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Complete a workout to see trends here.")
                )
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    oneRepMaxSection
                    volumeByCycleSection
                    personalRecordsSection
                    phaseComparisonSection
                }
                .padding()
            }
        }
        .onAppear {
            if selectedExercise == nil {
                selectedExercise = exercisesWithHistory.first
            }
        }
    }

    private var exercisesWithHistory: [Exercise] {
        exercises.filter { exercise in
            sessions.contains { session in
                session.entries.contains { $0.exercise?.persistentModelID == exercise.persistentModelID && $0.isComplete }
            }
        }
    }

    // MARK: - 1RM trend

    private var oneRepMaxSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated 1RM")
                .font(.headline)

            if exercisesWithHistory.isEmpty {
                Text("No completed sets yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(exercisesWithHistory, id: \.persistentModelID) { exercise in
                        Text(exercise.name).tag(Optional(exercise))
                    }
                }
                .pickerStyle(.menu)

                if let selectedExercise {
                    let points = ProgressCalculator.oneRepMaxTrend(exercise: selectedExercise, sessions: sessions)
                    if points.isEmpty {
                        Text("No completed sets for this exercise yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(points, id: \.date) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Est. 1RM", point.estimatedOneRepMax))
                                .foregroundStyle(.tint)
                            PointMark(x: .value("Date", point.date), y: .value("Est. 1RM", point.estimatedOneRepMax))
                                .foregroundStyle(.tint)
                        }
                        .frame(height: 200)
                    }
                }
            }
        }
    }

    // MARK: - Volume per muscle group per cycle

    private var volumeByCycleSection: some View {
        let program = programs.first
        let data = program.map { ProgressCalculator.volumeByCycle(sessions: sessions, anchor: $0.anchorDate) } ?? []

        return VStack(alignment: .leading, spacing: 8) {
            Text("Volume Per Cycle")
                .font(.headline)
            if data.isEmpty {
                Text("No completed sets yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("Cycle", "C\(point.cycleIndex + 1)"),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(by: .value("Group", point.muscleGroup.displayName))
                }
                .frame(height: 220)
            }
        }
    }

    // MARK: - PR feed

    private var personalRecordsSection: some View {
        let records = ProgressCalculator.personalRecords(sessions: sessions)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Personal Records")
                .font(.headline)
            if records.isEmpty {
                Text("No PRs logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records.prefix(10)) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.exerciseName)
                            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(record.summary)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    // MARK: - A/B comparison

    private var phaseComparisonSection: some View {
        let comparison = ProgressCalculator.phaseComparison(muscleGroup: selectedGroup, sessions: sessions)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Phase A vs. Phase B")
                .font(.headline)

            Picker("Muscle Group", selection: $selectedGroup) {
                ForEach(MuscleGroup.allCases) { group in
                    Text(group.displayName).tag(group)
                }
            }
            .pickerStyle(.menu)

            if comparison.phaseAAverageVolume == 0 && comparison.phaseBAverageVolume == 0 {
                Text("No completed sets for \(selectedGroup.displayName) yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    BarMark(x: .value("Phase", "A"), y: .value("Avg Volume", comparison.phaseAAverageVolume))
                        .foregroundStyle(.blue)
                    BarMark(x: .value("Phase", "B"), y: .value("Avg Volume", comparison.phaseBAverageVolume))
                        .foregroundStyle(.purple)
                }
                .frame(height: 160)
            }
        }
    }
}
