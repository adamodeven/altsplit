import SwiftUI

/// The payoff screen — body and lifting progress.
struct ProgressTabView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case body = "Body"
        case lifting = "Lifting"
        case erg = "Erg"
        case history = "History"
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
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom)

                TabView(selection: $section) {
                    BodyProgressView().tag(Section.body)
                    LiftingProgressView().tag(Section.lifting)
                    ErgProgressView().tag(Section.erg)
                    WorkoutHistoryView().tag(Section.history)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Progress")
            .tabBarMinimizeBehavior(.onScrollDown)
        }
    }
}
