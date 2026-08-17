import SwiftUI

/// Shown in the workout box's long-press context menu preview, so you can
/// see what's coming without committing to it.
struct WorkoutPreviewList: View {
    let day: ResolvedDay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day.title)
                .font(.headline)
            if day.exercises.isEmpty {
                Text(day.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(day.exercises, id: \.persistentModelID) { planned in
                    HStack {
                        Text(planned.exercise?.name ?? "—")
                        Spacer()
                        Text(planned.targetSummary)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(minWidth: 260, alignment: .leading)
    }
}
