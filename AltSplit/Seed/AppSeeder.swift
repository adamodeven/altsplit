import Foundation
import SwiftData

/// Populates a fresh store with the default exercise library and program so
/// the app is usable on first launch.
enum AppSeeder {
    static func seedIfNeeded(context: ModelContext) {
        let hasProgram = ((try? context.fetchCount(FetchDescriptor<Program>())) ?? 0) > 0
        guard !hasProgram else { return }

        let exercises = ExerciseLibrary.seed(into: context)
        _ = DefaultProgram.seed(context: context, exercises: exercises)

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save seeded data: \(error)")
        }
    }
}
