import SwiftUI

/// Three tabs in the Liquid Glass tab bar. On iOS 26 the tab bar picks up
/// the glass treatment automatically.
struct RootTabView: View {
    @State private var selection: AppTab = .home

    private let tabs = AppTab.allCases

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
        .gesture(swipeGesture)
    }

    /// Lets a horizontal swipe anywhere in the tab content move to the
    /// adjacent tab, in addition to tapping the tab bar.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical), abs(horizontal) > 60 else { return }
                guard let currentIndex = tabs.firstIndex(of: selection) else { return }

                if horizontal < 0, tabs.index(after: currentIndex) < tabs.endIndex {
                    selection = tabs[tabs.index(after: currentIndex)]
                } else if horizontal > 0, currentIndex > tabs.startIndex {
                    selection = tabs[tabs.index(before: currentIndex)]
                }
            }
    }
}
