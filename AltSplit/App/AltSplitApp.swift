import SwiftUI
import SwiftData

@main
struct AltSplitApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            Program.self,
            DayTemplate.self,
            Exercise.self,
            PlannedExercise.self,
            WorkoutSession.self,
            SetEntry.self,
            CardioResult.self,
            CheckIn.self,
            SupplementLog.self,
            SnoozeRecord.self,
        ])
        // UI tests launch with a fresh in-memory store so every run starts
        // from the same deterministic seeded state.
        let inMemory = ProcessInfo.processInfo.arguments.contains("UITEST_RESET")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        AppSeeder.seedIfNeeded(context: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
