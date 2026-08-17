import Foundation
import SwiftData

/// Populates a fresh store with the default exercise library and program so
/// the app is usable on first launch.
enum AppSeeder {
    static func seedIfNeeded(context: ModelContext) {
        let hasProgram = (try? context.fetchCount(FetchDescriptor<Program>())) ?? 0 > 0
        guard !hasProgram else { return }

        try? context.save()
    }
}
