import XCTest

/// 시뮬레이터가 직전 인스턴스 종료 직후의 재실행을 가끔 거부해서, 종료를 확인하고 실패하면 다시 실행한다.
func launchWatchApp(language: String = "ko") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-uitest", "-AppleLanguages", "(\(language))", "-AppleLocale", language == "ko" ? "ko_KR" : "en_US"]
    for _ in 1...5 {
        app.launch()
        // 앱이 떠 있고 운동 목록이 실제로 보일 때까지 확인한다. 아니면 종료 후 다시 실행.
        if app.wait(for: .runningForeground, timeout: 15), app.buttons.firstMatch.waitForExistence(timeout: 15) { return app }
        app.terminate()
        Thread.sleep(forTimeInterval: 5)
    }
    return app
}

final class HometsWatchFunctionalTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    override func tearDown() { XCUIApplication().terminate(); Thread.sleep(forTimeInterval: 4) }

    private func openFirstExercise() -> XCUIApplication {
        let app = launchWatchApp()
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
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "sets-after-crown"; attachment.lifetime = .keepAlways; add(attachment)

        app.buttons["logSet"].tap()
        XCTAssertTrue(app.staticTexts["restTime"].waitForExistence(timeout: 10), "세트 완료 후 휴식 타이머가 안 나옴 (세트 칸=\(planned) → \(value(app, "tile-sets")))")
        app.buttons["skipRest"].tap()
        Thread.sleep(forTimeInterval: 2)
        let shotAfter = XCTAttachment(screenshot: app.screenshot()); shotAfter.name = "after-skip"; shotAfter.lifetime = .keepAlways; add(shotAfter)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = "tree-after-skip"; tree.lifetime = .keepAlways; add(tree)
        XCTAssertTrue(app.buttons["logSet"].waitForExistence(timeout: 10))
        XCTAssertTrue(value(app, "tile-sets").hasPrefix("1/"), "세트 완료 후 진행 수가 1이 아님: \(value(app, "tile-sets"))")
    }

    // MARK: 언어

    private func firstExerciseButton(_ app: XCUIApplication, startingWith name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    func testEnglishTexts() throws {
        let app = launchWatchApp(language: "en")
        XCTAssertTrue(firstExerciseButton(app, startingWith: "Shoulder Press").waitForExistence(timeout: 10), "영어에서 운동 이름이 영어가 아님")
        app.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["logSet"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["tile-sets"].label, "SETS")
        XCTAssertEqual(app.buttons["tile-reps"].label, "REPS")
        XCTAssertEqual(app.buttons["logSet"].label, "Done")
        app.buttons["logSet"].tap()
        XCTAssertTrue(app.buttons["skipRest"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["skipRest"].label, "Skip")
    }

    func testKoreanTexts() throws {
        let app = launchWatchApp(language: "ko")
        XCTAssertTrue(firstExerciseButton(app, startingWith: "숄더 프레스").waitForExistence(timeout: 10), "한국어에서 운동 이름이 한국어가 아님")
        app.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["logSet"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["tile-sets"].label, "세트")
        XCTAssertEqual(app.buttons["tile-reps"].label, "횟수")
        XCTAssertEqual(app.buttons["logSet"].label, "세트 완료")
        app.buttons["logSet"].tap()
        XCTAssertTrue(app.buttons["skipRest"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["skipRest"].label, "건너뛰기")
    }
}
