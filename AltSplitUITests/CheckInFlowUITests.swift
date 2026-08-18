import XCTest

final class CheckInFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSaveIsDisabledUntilBothWeightAndPhotoExist() {
        let app = launchApp()
        let checkInBox = app.buttons["checkInBox"]
        XCTAssertTrue(checkInBox.waitForExistence(timeout: 5))
        checkInBox.tap()

        XCTAssertTrue(app.navigationBars["Check In"].waitForExistence(timeout: 3))
        let saveButton = app.buttons["saveCheckInButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        XCTAssertFalse(saveButton.isEnabled)

        let weightField = app.textFields["weightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 2))
        weightField.tap()
        weightField.typeText("181.4")
        app.navigationBars.firstMatch.tap() // dismiss keyboard

        // Weight alone is not enough — the model has no valid CheckIn with
        // a nil photo.
        XCTAssertFalse(saveButton.isEnabled)
    }

    func testCheckInFlowSavesAndFlipsBoxToNotDue() {
        let app = launchApp()
        let checkInBox = app.buttons["checkInBox"]
        XCTAssertTrue(checkInBox.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["WEIGH IN + PHOTO DUE"].exists)
        checkInBox.tap()

        XCTAssertTrue(app.navigationBars["Check In"].waitForExistence(timeout: 3))
        let saveButton = app.buttons["saveCheckInButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))

        let useTestPhoto = app.buttons["useTestPhotoButton"]
        XCTAssertTrue(useTestPhoto.waitForExistence(timeout: 3))
        useTestPhoto.tap()

        let weightField = app.textFields["weightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 2))
        weightField.tap()
        weightField.typeText("181.4")
        app.navigationBars.firstMatch.tap() // dismiss keyboard

        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(checkInBox.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["181.4 lb"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["WEIGH IN + PHOTO DUE"].exists)
    }

    func testRetakeClearsCapturedPhoto() {
        let app = launchApp()
        app.buttons["checkInBox"].tap()
        XCTAssertTrue(app.navigationBars["Check In"].waitForExistence(timeout: 3))

        app.buttons["useTestPhotoButton"].tap()
        let retakeButton = app.buttons["retakeButton"]
        XCTAssertTrue(retakeButton.waitForExistence(timeout: 3))

        retakeButton.tap()
        XCTAssertTrue(app.buttons["useTestPhotoButton"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["saveCheckInButton"].isEnabled)
    }
}
