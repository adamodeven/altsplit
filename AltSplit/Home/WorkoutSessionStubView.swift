import SwiftUI

/// Placeholder for the active workout logger. The real set-by-set logging
/// UI (lift / hold / bodyweight fields, rest timer) is a separate increment
/// — this exists so the workout box has somewhere to go.
struct WorkoutSessionStubView: View {
    let day: ResolvedDay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(day.title) {
                    ForEach(day.exercises, id: \.persistentModelID) { planned in
                        HStack {
                            Text(planned.exercise?.name ?? "—")
                            Spacer()
                            Text(planned.targetSummary)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(day.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
