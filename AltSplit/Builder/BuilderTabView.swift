import SwiftUI

/// Placeholder for the Builder tab (split editor and exercise library).
/// Built out in a later step.
struct BuilderTabView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Builder",
                systemImage: "hammer.fill",
                description: Text("Split editor and exercise library land here.")
            )
            .navigationTitle("Builder")
            .tabBarMinimizeBehavior(.onScrollDown)
        }
    }
}
