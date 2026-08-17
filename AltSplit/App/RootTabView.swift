import SwiftUI

/// Three tabs in the Liquid Glass tab bar. On iOS 26 the tab bar picks up
/// the glass treatment automatically.
struct RootTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(selection: $selection)
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressTabView()
            }
            Tab("Builder", systemImage: "hammer.fill", value: AppTab.builder) {
                BuilderTabView()
            }
        }
    }
}
