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

        // Finish only replaces Minimize once every set is checked off, so
        // right after opening either one signals a training day.
        let finishButton = app.buttons["Finish"]
        let minimizeButton = app.buttons["Minimize"]
        if finishButton.waitForExistence(timeout: 2) || minimizeButton.exists {
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
        let minimizeButton = app.buttons["Minimize"]
        guard finishButton.waitForExistence(timeout: 2) || minimizeButton.exists else {
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

        // With other sets on the day left unchecked, end the workout early
        // via the same "Save & End Workout" escape hatch behind Cancel that
        // a real user would use.
        if finishButton.exists {
            finishButton.tap()
        } else {
            app.buttons["Cancel"].tap()
            XCTAssertTrue(app.buttons["Save & End Workout"].waitForExistence(timeout: 2))
            app.buttons["Save & End Workout"].tap()
        }
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
    }

    func testMinimizingAWorkoutPreservesProgressAndResumes() {
        let app = launchApp()
        let workoutBox = app.buttons["workoutBox"]
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
        workoutBox.tap()

        let minimizeButton = app.buttons["Minimize"]
        guard minimizeButton.waitForExistence(timeout: 2) else {
            return // rest day, or a day with exactly one set — nothing to minimize
        }

        let checkmarks = app.buttons.matching(identifier: "setCheckmark")
        XCTAssertTrue(checkmarks.firstMatch.waitForExistence(timeout: 2))
        checkmarks.firstMatch.tap()

        // Minimize hides the logger without ending the session.
        minimizeButton.tap()
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["In progress · tap to resume"].waitForExistence(timeout: 3))

        // Visiting another tab and coming back doesn't lose anything either.
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 3))

        // Reopening resumes the same session — the set checked before
        // minimizing is still checked, not reset to a fresh workout.
        workoutBox.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
        let firstCheckmark = app.buttons.matching(identifier: "setCheckmark").firstMatch
        XCTAssertTrue(firstCheckmark.waitForExistence(timeout: 3))
        XCTAssertTrue(firstCheckmark.isSelected)

        app.buttons["Cancel"].tap()
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
    }

    func testFlickScrollingStillWorksAndDismissesKeyboard() {
        let app = launchApp()
        let workoutBox = app.buttons["workoutBox"]
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
        workoutBox.tap()

        guard app.buttons["Minimize"].waitForExistence(timeout: 2) || app.buttons["Finish"].exists else {
            return // rest day
        }

        let weightField = app.textFields["lb"].firstMatch
        guard weightField.waitForExistence(timeout: 2) else { return }
        weightField.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 2))

        // A plain quick swipe (not a held drag) must still reach the list's
        // own scroll gesture, not get swallowed by the reorder gesture on
        // the rows it passes over — and that scroll should dismiss the
        // keyboard interactively, same as any other scrollable form.
        app.swipeUp()
        XCTAssertFalse(app.keyboards.element.waitForExistence(timeout: 2))
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
