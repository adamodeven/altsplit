import XCTest

/// Drives the app through its real UI rather than just inspecting code.
/// Launches with `UITEST_RESET` so every run starts from the same
/// deterministic freshly-seeded, in-memory store (see AltSplitApp.init).
final class HomeFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeShowsSeededWorkoutBox() {
        let app = launchApp()
        let workoutBox = app.buttons["workoutBox"]
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
    }

    func testTappingWorkoutBoxOpensLoggerOnATrainingDayAndDoesNothingOnRest() {
        let app = launchApp()
        let workoutBox = app.buttons["workoutBox"]
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
        workoutBox.tap()

        let finishButton = app.buttons["Finish"]
        if finishButton.waitForExistence(timeout: 2) {
            // Training day: the logger opened. Confirm we can get back out.
            let cancelButton = app.buttons["Cancel"]
            XCTAssertTrue(cancelButton.exists)
            cancelButton.tap()
            XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
        } else {
            // Rest day: nothing should have opened.
            XCTAssertTrue(workoutBox.exists)
        }
    }

    func testLoggingASetAndFinishingReturnsHome() {
        let app = launchApp()
        let workoutBox = app.buttons["workoutBox"]
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
        workoutBox.tap()

        let finishButton = app.buttons["Finish"]
        guard finishButton.waitForExistence(timeout: 2) else {
            // Rest day today — nothing to log, nothing to assert further.
            return
        }

        // Fill in the first set's fields, whatever type they are, then mark
        // it complete via the circle toggle.
        let firstField = app.textFields.firstMatch
        if firstField.waitForExistence(timeout: 2) {
            firstField.tap()
            firstField.typeText("135")
        }
        let toolbars = app.navigationBars.firstMatch
        toolbars.tap() // dismiss keyboard

        let checkmarks = app.buttons.matching(identifier: "setCheckmark")
        if checkmarks.count > 0 {
            checkmarks.firstMatch.tap()
        }

        finishButton.tap()
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
    }

    func testProteinToggleAdvancesStreak() {
        let app = launchApp()
        let protein = app.buttons["supplementBox.protein"]
        XCTAssertTrue(protein.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 day streak"].waitForExistence(timeout: 2))

        protein.tap()
        XCTAssertTrue(app.staticTexts["1 day streak"].waitForExistence(timeout: 2))

        protein.tap()
        XCTAssertTrue(app.staticTexts["0 day streak"].waitForExistence(timeout: 2))
    }

    func testCheckInBoxIsDueOnFreshStoreAndOpensCaptureSheet() {
        let app = launchApp()
        let checkInBox = app.buttons["checkInBox"]
        XCTAssertTrue(checkInBox.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["WEIGH IN + PHOTO DUE"].exists)

        checkInBox.tap()
        XCTAssertTrue(app.navigationBars["Check In"].waitForExistence(timeout: 3))

        app.buttons["Close"].tap()
        XCTAssertTrue(checkInBox.waitForExistence(timeout: 5))
    }

    func testLongPressingWorkoutBoxShowsPreviewMenu() {
        let app = launchApp()
        let workoutBox = app.buttons["workoutBox"]
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
        workoutBox.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Start Workout"].waitForExistence(timeout: 3))
    }

    func testTabsSwitchBetweenPlaceholderScreens() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["workoutBox"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Builder"].tap()
        XCTAssertTrue(app.navigationBars["Builder"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["workoutBox"].waitForExistence(timeout: 3))
    }
}
