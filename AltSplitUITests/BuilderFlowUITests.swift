import XCTest

final class BuilderFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Exercise library

    func testAddingACustomExerciseShowsItInTheLibrary() {
        let app = launchApp()
        app.tabBars.buttons["Builder"].tap()
        app.buttons["Exercise Library"].tap()
        XCTAssertTrue(app.navigationBars["Exercise Library"].waitForExistence(timeout: 3))

        app.buttons["addExerciseButton"].tap()
        XCTAssertTrue(app.navigationBars["New Exercise"].waitForExistence(timeout: 3))

        let saveButton = app.buttons["saveExerciseButton"]
        XCTAssertFalse(saveButton.isEnabled) // empty name

        let nameField = app.textFields["exerciseNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Zercher Squat")

        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.navigationBars["Exercise Library"].waitForExistence(timeout: 3))
        // Sorts alphabetically last — needs scrolling into view.
        XCTAssertTrue(scrollToFind(app.staticTexts["Zercher Squat"], in: app))
    }

    func testNewExerciseDetailShowsAsCustomWithNoUsageOrHistory() {
        let app = launchApp()
        app.tabBars.buttons["Builder"].tap()
        app.buttons["Exercise Library"].tap()
        app.buttons["addExerciseButton"].tap()

        let nameField = app.textFields["exerciseNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("Cossack Squat")
        app.buttons["saveExerciseButton"].tap()

        XCTAssertTrue(app.navigationBars["Exercise Library"].waitForExistence(timeout: 3))
        let row = app.staticTexts["Cossack Squat"]
        XCTAssertTrue(scrollToFind(row, in: app))
        row.tap()

        XCTAssertTrue(app.navigationBars["Cossack Squat"].waitForExistence(timeout: 3))
        // LabeledContent merges title + value into one accessibility
        // element, same as the split editor's focus row.
        XCTAssertTrue(app.staticTexts["Source, Custom"].exists)
        XCTAssertTrue(app.staticTexts["Not currently scheduled in the split."].exists)
        XCTAssertTrue(app.staticTexts["No sets logged yet."].exists)
    }

    func testFilteringByMuscleGroupNarrowsTheList() {
        let app = launchApp()
        app.tabBars.buttons["Builder"].tap()
        app.buttons["Exercise Library"].tap()
        XCTAssertTrue(app.navigationBars["Exercise Library"].waitForExistence(timeout: 3))
        XCTAssertTrue(scrollToFind(app.staticTexts["Deadlift"], in: app))

        app.buttons["filterMenuButton"].tap()
        app.buttons["Muscle Group"].tap()
        app.buttons["Chest"].tap()

        // Deadlift (back) no longer matches the Chest filter.
        XCTAssertTrue(scrollToFind(app.staticTexts["Barbell Bench Press"], in: app, maxSwipes: 20))
        XCTAssertFalse(app.staticTexts["Deadlift"].exists)
    }

    // MARK: - Split editor

    func testAddingAnExerciseToADayPoolShowsUpInThePreview() {
        let app = launchApp()
        app.tabBars.buttons["Builder"].tap()
        app.buttons["Split Editor"].tap()
        XCTAssertTrue(app.navigationBars["Split Editor"].waitForExistence(timeout: 3))

        app.staticTexts["Monday"].tap()
        XCTAssertTrue(app.navigationBars["Monday"].waitForExistence(timeout: 3))

        // Two "Add Exercise" buttons: Phase A section then Phase B.
        let addButtons = app.buttons["Add Exercise"]
        XCTAssertTrue(addButtons.firstMatch.waitForExistence(timeout: 3))
        addButtons.firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Add Exercise"].waitForExistence(timeout: 3))
        // Not already in Monday's pool, so its appearance afterward is
        // unambiguous evidence the add actually landed.
        let skullCrusher = app.staticTexts["Skull Crusher"]
        XCTAssertTrue(scrollToFind(skullCrusher, in: app, maxSwipes: 20))
        skullCrusher.tap()

        XCTAssertTrue(app.navigationBars["Monday"].waitForExistence(timeout: 3))
        XCTAssertTrue(scrollToFind(app.staticTexts["Skull Crusher"], in: app))
    }

    func testEditingATargetChangesItsSummary() {
        let app = launchApp()
        app.tabBars.buttons["Builder"].tap()
        app.buttons["Split Editor"].tap()
        app.staticTexts["Monday"].tap()
        XCTAssertTrue(app.navigationBars["Monday"].waitForExistence(timeout: 3))

        // Monday's seeded Phase A pool starts with Deadlift, 3 x 5.
        XCTAssertTrue(app.staticTexts["Deadlift"].waitForExistence(timeout: 3))
        app.staticTexts["Deadlift"].tap()
        XCTAssertTrue(app.navigationBars["Edit Target"].waitForExistence(timeout: 3))

        // Steppers expose their +/- as child buttons, not a single tappable
        // label — bump sets from 3 to 4 via the Increment child.
        let setsStepper = app.steppers["Sets: 3"]
        XCTAssertTrue(setsStepper.waitForExistence(timeout: 3))
        setsStepper.buttons["Increment"].tap()
        XCTAssertTrue(app.steppers["Sets: 4"].waitForExistence(timeout: 2))

        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Monday"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["4 × 5"].waitForExistence(timeout: 3))
    }

    func testSettingDoubleDayFocusUpdatesSplitEditor() {
        let app = launchApp()
        app.tabBars.buttons["Builder"].tap()
        app.buttons["Split Editor"].tap()
        XCTAssertTrue(app.navigationBars["Split Editor"].waitForExistence(timeout: 3))

        // LabeledContent merges title + value into one accessibility
        // element, so the row is queried as a single combined-label button.
        let focusRow = app.buttons["Current Focus, Shoulders"]
        XCTAssertTrue(focusRow.waitForExistence(timeout: 3))
        focusRow.tap()

        XCTAssertTrue(app.navigationBars["Double Day Focus"].waitForExistence(timeout: 3))
        // An unselected row with just a text label fully merges into its
        // Button — there's no separate StaticText to query here.
        app.buttons["Legs"].tap()

        XCTAssertTrue(app.navigationBars["Split Editor"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Current Focus, Legs"].waitForExistence(timeout: 3))
    }
}
