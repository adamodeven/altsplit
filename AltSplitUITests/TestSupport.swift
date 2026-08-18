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

    /// Swipes up on the frontmost list until `element` exists, or gives up
    /// after `maxSwipes`. Needed for lists longer than one screen — rows
    /// off-screen aren't in the accessibility tree at all.
    @discardableResult
    func scrollToFind(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 15) -> Bool {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
        return element.exists && element.isHittable
    }
}
