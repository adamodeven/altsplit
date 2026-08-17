import SwiftUI

/// The payoff screen — body and lifting progress.
struct ProgressTabView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case body = "Body"
        case lifting = "Lifting"
        var id: String { rawValue }
    }

    @State private var section: Section = .body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                switch section {
                case .body: BodyProgressView()
                case .lifting: LiftingProgressView()
                }
            }
            .navigationTitle("Progress")
            .tabBarMinimizeBehavior(.onScrollDown)
        }
    }
}
