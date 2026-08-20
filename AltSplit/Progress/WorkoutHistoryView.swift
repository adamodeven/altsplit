import SwiftUI
import SwiftData

/// Every finished workout, most recent first. Sessions that were started but
/// never finished (no `endedAt`) don't show here — there's nothing to review
/// yet for those.
struct WorkoutHistoryView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    private var finishedSessions: [WorkoutSession] {
        sessions.filter { $0.endedAt != nil }
    }

    var body: some View {
        Group {
            if finishedSessions.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Finished workouts will show up here.")
                )
                .padding(.top, 60)
            } else {
                List(finishedSessions, id: \.persistentModelID) { session in
                    NavigationLink {
                        WorkoutHistoryDetailView(session: session)
                    } label: {
                        row(for: session)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func row(for session: WorkoutSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(SessionSummary.title(for: session))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let duration = session.duration {
                    Text(SessionSummary.formattedDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Shared bits between the history list and detail screen.
enum SessionSummary {
    /// Same derivation `DayTemplate.title` uses for a planned day — but read
    /// off what was actually logged, so history stays accurate even if the
    /// split has since changed.
    static func title(for session: WorkoutSession) -> String {
        if session.cardioResult != nil {
            return "Erg"
        }
        let present = Set(session.entries.compactMap(\.exercise?.muscleGroup))
        let groups = MuscleGroup.allCases.filter(present.contains)
        return groups.isEmpty
            ? session.weekday.displayName
            : groups.map(\.displayName).joined(separator: " + ")
    }

    static func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return minutes < 1 ? "<1 min" : "\(minutes) min"
    }
}
