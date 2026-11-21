import XCTest

final class HometsWatchScreenshotTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureWorkoutFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 15))
        shot(app, "01-exercise-list")

        app.buttons.firstMatch.tap()
        let log = app.buttons["logSet"]
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        app.buttons["weight-plus"].tap()
        app.buttons["weight-plus"].tap()
        app.buttons["reps-plus"].tap()
        shot(app, "02-weight-reps-sets")

        log.tap()
        XCTAssertTrue(app.staticTexts["restTime"].waitForExistence(timeout: 10))
        shot(app, "03-rest-timer")

        app.buttons["skipRest"].tap()
        XCTAssertTrue(app.buttons["logSet"].waitForExistence(timeout: 10))
        shot(app, "04-after-rest")
    }
}
