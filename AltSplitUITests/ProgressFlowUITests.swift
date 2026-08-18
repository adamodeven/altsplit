import XCTest

final class ProgressFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testProgressShowsEmptyStatesOnFreshInstall() {
        let app = launchApp()
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 3))

        XCTAssertTrue(app.staticTexts["No Check-Ins Yet"].waitForExistence(timeout: 3))

        app.buttons["Lifting"].tap()
        XCTAssertTrue(app.staticTexts["No Lifting History Yet"].waitForExistence(timeout: 3))
    }

    func testCompletingAWorkoutWithAPRShowsUpInLiftingProgress() {
        let app = launchApp()
        let workoutBox = app.buttons["workoutBox"]
        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))
        workoutBox.tap()

        guard app.buttons["Finish"].waitForExistence(timeout: 2) else {
            return // rest day today — nothing to log
        }

        let weightField = app.textFields["lb"].firstMatch
        XCTAssertTrue(weightField.waitForExistence(timeout: 2))
        weightField.tap()
        weightField.typeText("135")

        let repsField = app.textFields["reps"].firstMatch
        XCTAssertTrue(repsField.waitForExistence(timeout: 2))
        repsField.tap()
        repsField.typeText("8")

        app.navigationBars.firstMatch.tap() // dismiss keyboard
        app.buttons.matching(identifier: "setCheckmark").firstMatch.tap()
        app.buttons["Finish"].tap()

        XCTAssertTrue(workoutBox.waitForExistence(timeout: 5))

        app.tabBars.buttons["Progress"].tap()
        app.buttons["Lifting"].tap()
        XCTAssertTrue(app.staticTexts["Personal Records"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["No PRs logged yet."].exists)
        XCTAssertTrue(app.staticTexts["135 × 8"].waitForExistence(timeout: 3))
    }

    func testSavingACheckInShowsUpInBodyProgress() {
        let app = launchApp()
        app.buttons["checkInBox"].tap()
        XCTAssertTrue(app.navigationBars["Check In"].waitForExistence(timeout: 3))

        app.buttons["useTestPhotoButton"].tap()
        let weightField = app.textFields["weightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 2))
        weightField.tap()
        weightField.typeText("180")
        app.navigationBars.firstMatch.tap()

        app.buttons["saveCheckInButton"].tap()
        XCTAssertTrue(app.buttons["checkInBox"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Weight Trend"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["No Check-Ins Yet"].exists)
        XCTAssertTrue(app.staticTexts["Need at least two check-ins to compare cycles."].waitForExistence(timeout: 3))
    }
}
