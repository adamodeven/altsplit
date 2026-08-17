import SwiftUI
import SwiftData

/// Temporary placeholder so the app has something on screen while the data
/// layer is being verified. Replaced by the real bento home in a later step.
struct ContentView: View {
    @Query private var programs: [Program]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                if let program = programs.first {
                    let resolver = DayResolver(program: program)
                    let today = resolver.resolve(for: .now)

                    Section("Today") {
                        LabeledContent("Phase", value: today.phase.displayName)
                        LabeledContent("Weekday", value: today.weekday.displayName)
                        LabeledContent("Title", value: today.title)
                        LabeledContent("Subtitle", value: today.subtitle)
                    }

                    Section("This week") {
                        ForEach(resolver.resolveWeek(containing: .now), id: \.date) { day in
                            VStack(alignment: .leading) {
                                Text("\(day.weekday.abbreviation) · \(day.title)")
                                    .font(.headline)
                                Text(day.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        LabeledContent("Exercises seeded", value: "\(exerciseCount)")
                    }
                } else {
                    Text("No program seeded")
                }
            }
            .navigationTitle("AltSplit")
        }
    }

    private var exerciseCount: Int {
        (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
    }
}
