import XCTest

final class HometsWatchScreenshotTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    override func tearDown() { XCUIApplication().terminate(); Thread.sleep(forTimeInterval: 4) }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureWorkoutFlow() throws { try captureFlow(language: "ko", prefix: "") }
    func testCaptureWorkoutFlowEnglish() throws { try captureFlow(language: "en", prefix: "en-") }

    private func captureFlow(language: String, prefix: String) throws {
        let app = launchWatchApp(language: language)
        let shot = { (app: XCUIApplication, name: String) in self.shot(app, prefix + name) }

        XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 15))
        shot(app, "01-exercise-list")

        app.buttons.firstMatch.tap()
        let log = app.buttons["logSet"]
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        app.buttons["tile-weight"].tap()
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.3)
        shot(app, "02-weight-reps-sets")

        log.tap()
        XCTAssertTrue(app.staticTexts["restTime"].waitForExistence(timeout: 10))
        shot(app, "03-rest-timer")

        app.buttons["skipRest"].tap()
        XCTAssertTrue(app.buttons["logSet"].waitForExistence(timeout: 10))
        shot(app, "04-after-rest")
    }
}
