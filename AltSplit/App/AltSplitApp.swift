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
        let configuration = ModelConfiguration(schema: schema)
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
