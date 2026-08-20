import SwiftUI
import SwiftData
import Charts

struct ErgProgressView: View {
    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @Query private var programs: [Program]

    var body: some View {
        ScrollView {
            if sessions.allSatisfy({ $0.cardioResult == nil }) {
                ContentUnavailableView(
                    "No Erg History Yet",
                    systemImage: "figure.rower",
                    description: Text("Complete an erg workout to see trends here.")
                )
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    splitTrendSection
                    distanceByCycleSection
                    personalRecordsSection
                }
                .padding()
            }
        }
    }

    // MARK: - Split trend

    private var splitTrendSection: some View {
        let points = ProgressCalculator.splitTrend(sessions: sessions)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Avg. Split")
                .font(.headline)

            if points.isEmpty {
                Text("No completed erg sessions yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Split", point.split))
                        .foregroundStyle(.tint)
                    PointMark(x: .value("Date", point.date), y: .value("Split", point.split))
                        .foregroundStyle(.tint)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let split = value.as(TimeInterval.self) {
                                Text(formattedSplit(split))
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(reversed: true))
                .frame(height: 200)
            }
        }
    }

    private func formattedSplit(_ split: TimeInterval) -> String {
        let minutes = Int(split) / 60
        let seconds = Int(split) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Distance per cycle

    private var distanceByCycleSection: some View {
        let program = programs.first
        let data = program.map { ProgressCalculator.distanceByCycle(sessions: sessions, anchor: $0.anchorDate) } ?? []

        return VStack(alignment: .leading, spacing: 8) {
            Text("Distance Per Cycle")
                .font(.headline)
            if data.isEmpty {
                Text("No completed erg sessions yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("Cycle", "C\(point.cycleIndex + 1)"),
                        y: .value("Meters", point.totalMeters)
                    )
                    .foregroundStyle(.tint)
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - PR feed

    private var personalRecordsSection: some View {
        let records = ProgressCalculator.ergPersonalRecords(sessions: sessions)
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
                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(record.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
