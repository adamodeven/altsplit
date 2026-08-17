import SwiftUI

/// Placeholder for the Progress tab (body, lifting, and erg charts). Built
/// out in a later step.
struct ProgressTabView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Progress",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Weight trend, lifting 1RM, and erg splits land here.")
            )
            .navigationTitle("Progress")
            .tabBarMinimizeBehavior(.onScrollDown)
        }
    }
}
