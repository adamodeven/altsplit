import XCTest

extension XCTestCase {
    /// Launches with `UITEST_RESET` so every run starts from the same
    /// deterministic, freshly-seeded, in-memory store (see AltSplitApp.init).
    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET"]
        app.launch()
        return app
    }
}
