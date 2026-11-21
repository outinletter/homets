import XCTest

final class HometsWatchFunctionalTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func openFirstExercise() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 15))
        app.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["logSet"].waitForExistence(timeout: 10))
        return app
    }

    private func value(_ app: XCUIApplication, _ id: String) -> String {
        (app.buttons[id].value as? String) ?? "?"
    }

    /// 값이 `old`에서 바뀔 때까지 최대 5초 기다린다.
    private func waitForChange(_ app: XCUIApplication, _ id: String, from old: String) -> String {
        let deadline = Date().addingTimeInterval(5)
        var now = value(app, id)
        while now == old && Date() < deadline { Thread.sleep(forTimeInterval: 0.3); now = value(app, id) }
        return now
    }

    func testCrownChangesOnlySelectedTile() throws {
        let app = openFirstExercise()
        let weight0 = value(app, "tile-weight"), reps0 = value(app, "tile-reps")

        app.buttons["tile-weight"].tap()
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)
        let weight1 = waitForChange(app, "tile-weight", from: weight0)
        XCTAssertNotEqual(weight1, weight0, "크라운이 무게를 바꾸지 못함")
        XCTAssertEqual(value(app, "tile-reps"), reps0, "무게를 바꿨는데 횟수가 같이 바뀜")

        app.buttons["tile-reps"].tap()
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.5)
        let reps1 = waitForChange(app, "tile-reps", from: reps0)
        XCTAssertNotEqual(reps1, reps0, "크라운이 횟수를 바꾸지 못함")
        XCTAssertEqual(value(app, "tile-weight"), weight1, "횟수를 바꿨는데 무게가 같이 바뀜")
    }

    func testSetsTileAndLogFlow() throws {
        let app = openFirstExercise()
        XCTAssertEqual(value(app, "tile-sets"), "0/3")

        app.buttons["tile-sets"].tap()
        XCUIDevice.shared.rotateDigitalCrown(delta: 0.3)
        let planned = waitForChange(app, "tile-sets", from: "0/3")
        XCTAssertNotEqual(planned, "0/3", "크라운이 세트 수를 바꾸지 못함")

        app.buttons["logSet"].tap()
        XCTAssertTrue(app.staticTexts["restTime"].waitForExistence(timeout: 10), "세트 완료 후 휴식 타이머가 안 나옴")
        app.buttons["skipRest"].tap()
        XCTAssertTrue(app.buttons["logSet"].waitForExistence(timeout: 10))
        XCTAssertTrue(value(app, "tile-sets").hasPrefix("1/"), "세트 완료 후 진행 수가 1이 아님: \(value(app, "tile-sets"))")
    }
}
