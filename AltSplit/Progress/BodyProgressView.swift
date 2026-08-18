import SwiftUI
import SwiftData
import Charts

struct BodyProgressView: View {
    @Query(sort: \CheckIn.date) private var checkIns: [CheckIn] // ascending

    @State private var compareLeftIndex = 0
    @State private var compareRightIndex = 0

    var body: some View {
        ScrollView {
            if checkIns.isEmpty {
                ContentUnavailableView(
                    "No Check-Ins Yet",
                    systemImage: "camera",
                    description: Text("Weigh in to start tracking your trend.")
                )
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    weightChart
                    photoStrip
                    compareSection
                    cycleDeltas
                }
                .padding()
            }
        }
        .onAppear {
            compareLeftIndex = 0
            compareRightIndex = checkIns.count - 1
        }
    }

    // MARK: - Weight trend

    private var weightChart: some View {
        let points = ProgressCalculator.weightTrend(checkIns: checkIns)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Weight Trend")
                .font(.headline)
            Chart {
                ForEach(points, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Weight", point.pounds))
                        .foregroundStyle(.secondary)
                        .symbol(.circle)
                }
                ForEach(points, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Rolling Average", point.rollingAverage))
                        .foregroundStyle(.tint)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .frame(height: 220)
        }
    }

    // MARK: - Photo strip

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos")
                .font(.headline)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(checkIns, id: \.persistentModelID) { checkIn in
                        VStack(spacing: 4) {
                            thumbnail(for: checkIn)
                                .frame(width: 70, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text("C\(checkIn.cycleIndex + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Two-up compare

    private var compareSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compare")
                .font(.headline)

            HStack(spacing: 12) {
                comparePane(index: $compareLeftIndex)
                comparePane(index: $compareRightIndex)
            }
        }
    }

    private func comparePane(index: Binding<Int>) -> some View {
        VStack(spacing: 8) {
            thumbnail(for: checkIns[index.wrappedValue])
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if checkIns.count > 1 {
                Slider(
                    value: Binding(
                        get: { Double(index.wrappedValue) },
                        set: { index.wrappedValue = Int($0.rounded()) }
                    ),
                    in: 0...Double(checkIns.count - 1),
                    step: 1
                )
            }
            Text(checkIns[index.wrappedValue].date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Cycle deltas

    private var cycleDeltas: some View {
        let deltas = ProgressCalculator.cycleOverCycleDeltas(checkIns: checkIns)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Cycle-Over-Cycle")
                .font(.headline)
            if deltas.isEmpty {
                Text("Need at least two check-ins to compare cycles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(deltas) { delta in
                    HStack {
                        Text("Cycle \(delta.fromCycle + 1) → \(delta.toCycle + 1)")
                        Spacer()
                        Text(String(format: "%+.1f lb", delta.deltaPounds))
                            .foregroundStyle(delta.deltaPounds < 0 ? .green : (delta.deltaPounds > 0 ? .orange : .secondary))
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func thumbnail(for checkIn: CheckIn) -> some View {
        if let image = PhotoStore.load(checkIn.photoRef) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color(.secondarySystemBackground))
        }
    }
}
