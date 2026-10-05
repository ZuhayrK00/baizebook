import XCTest

final class JourneyTests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    @MainActor func testClearAllDataRequiresConfirmationAndStaysEmptyAfterRelaunch() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-tests", "--reset-testdata", "--demo"]; app.launch()
        app.buttons["Settings"].firstMatch.tap()
        reveal(app.buttons["clear-all-data"], in: app); app.buttons["clear-all-data"].tap()
        XCTAssertTrue(app.staticTexts["Clear all data?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["confirm-clear-all-data"].exists)
        attach(app, "11-clear-all-data-warning")
        app.buttons["Cancel"].tap(); app.buttons["Play"].firstMatch.tap()
        XCTAssertTrue(app.buttons["resume-match"].waitForExistence(timeout: 5))
        app.buttons["Settings"].firstMatch.tap()
        reveal(app.buttons["clear-all-data"], in: app); app.buttons["clear-all-data"].tap()
        reveal(app.buttons["confirm-clear-all-data"], in: app); app.buttons["confirm-clear-all-data"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5)); app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["new-match"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["resume-match"].exists)
        app.buttons["Players"].firstMatch.tap(); XCTAssertTrue(app.staticTexts["Your table starts here"].waitForExistence(timeout: 5))
        app.buttons["History"].firstMatch.tap(); XCTAssertTrue(app.staticTexts["Your time at the table"].waitForExistence(timeout: 5))
        app.terminate(); app.launchArguments = ["--ui-tests"]; app.launch()
        XCTAssertTrue(app.buttons["new-match"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["resume-match"].exists)
        app.buttons["Players"].firstMatch.tap(); XCTAssertTrue(app.staticTexts["Your table starts here"].waitForExistence(timeout: 5))
        app.buttons["add-player"].tap(); let name = app.textFields["player-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Fresh player"); app.buttons["save-player"].tap()
        XCTAssertTrue(app.staticTexts["Fresh player"].waitForExistence(timeout: 5))
    }
    @MainActor func testInlineMultipleRedsAndWinnerSheet() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-tests", "--reset-testdata", "--demo"]; app.launch()
        app.buttons["resume-match"].tap()
        XCTAssertFalse(app.buttons["multiple-reds"].exists)
        app.buttons["ball-1"].tap(); XCTAssertTrue(app.buttons["multiple-reds"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["multiple-reds"].isHittable); XCTAssertTrue(app.buttons["end-turn"].isHittable); XCTAssertTrue(app.buttons["undo"].isHittable)
        XCTAssertLessThan(app.buttons["multiple-reds"].frame.maxY, app.buttons["foul"].frame.minY)
        attach(app,"08-inline-multiple-reds")
        app.buttons["multiple-reds"].tap(); attach(app,"10-multiple-reds-sheet"); app.buttons["More reds"].tap(); app.buttons["record-multiple-reds"].tap()
        XCTAssertEqual(app.staticTexts["score-0"].label,"27"); XCTAssertFalse(app.buttons["multiple-reds"].exists)
        app.buttons["undo"].tap(); XCTAssertEqual(app.staticTexts["score-0"].label,"24")
        app.buttons["redo"].tap(); XCTAssertEqual(app.staticTexts["score-0"].label,"27")
        app.buttons["ball-7"].tap(); XCTAssertEqual(app.staticTexts["score-0"].label,"34")
        app.buttons["match-menu"].tap(); XCTAssertFalse(app.buttons["Multiple reds"].exists); app.buttons["Finish frame"].tap()
        XCTAssertTrue(app.staticTexts["Who won this frame?"].waitForExistence(timeout:5)); XCTAssertTrue(app.buttons["Alex wins the frame"].isHittable)
        attach(app,"09-frame-winner-sheet")
        app.buttons["Cancel"].tap(); XCTAssertEqual(app.staticTexts["score-0"].label,"34")
        app.buttons["match-menu"].tap(); app.buttons["Finish frame"].tap(); app.buttons["Alex wins the frame"].tap()
        XCTAssertTrue(app.buttons["Next frame"].waitForExistence(timeout:5))
    }
    @MainActor func testPlayerMatchScoringFoulUndoAndRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-tests", "--reset-testdata"]
        app.launch()
        app.buttons["Players"].firstMatch.tap()
        for name in ["Alex", "Jamie"] {
            app.buttons["add-player"].tap()
            let field = app.textFields["player-name"]
            XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
            app.buttons["save-player"].tap()
        }
        app.buttons["Play"].firstMatch.tap()
        app.buttons["new-match"].tap()
        reveal(app.buttons["start-match"], in: app); app.buttons["start-match"].tap()
        let red = app.buttons["ball-1"]
        XCTAssertTrue(red.waitForExistence(timeout: 5)); XCTAssertTrue(red.isEnabled)
        XCTAssertFalse(app.buttons["ball-7"].isEnabled)
        red.tap(); app.buttons["ball-7"].tap()
        XCTAssertEqual(app.staticTexts["score-0"].label, "8")
        app.buttons["undo"].tap(); XCTAssertEqual(app.staticTexts["score-0"].label, "1")
        app.buttons["ball-7"].tap()
        app.buttons["end-turn"].tap()
        XCTAssertEqual(app.staticTexts["current-turn"].label, "Jamie's turn")
        app.buttons["foul"].tap(); app.buttons["record-foul"].tap()
        XCTAssertEqual(app.staticTexts["score-0"].label, "12")
        app.terminate(); app.launchArguments = ["--ui-tests"]; app.launch()
        app.buttons["resume-match"].tap()
        XCTAssertEqual(app.staticTexts["score-0"].label, "12")
        XCTAssertEqual(app.staticTexts["current-turn"].label, "Alex's turn")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["History"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Alex vs Jamie"].waitForExistence(timeout: 5))
    }
    @MainActor func testPhoneScreenshots() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-tests", "--reset-testdata", "--demo"]; app.launch()
        attach(app, "01-home")
        app.buttons["resume-match"].tap()
        XCTAssertTrue(app.buttons["ball-1"].isHittable)
        XCTAssertTrue(app.buttons["end-turn"].isHittable)
        XCTAssertTrue(app.buttons["undo"].isHittable)
        XCTAssertTrue(app.buttons["redo"].isHittable)
        XCTAssertTrue(app.buttons["ball-1"].waitForExistence(timeout: 5))
        app.buttons["ball-1"].tap()
        XCTAssertEqual(app.staticTexts["score-0"].label, "25")
        attach(app, "02-scoring")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Players"].firstMatch.tap()
        app.staticTexts["Alex"].firstMatch.tap(); attach(app, "03-statistics")
        app.buttons["Settings"].firstMatch.tap(); attach(app, "04-settings")
    }
    @MainActor func testTraditionalScoreboardAndFrameResultUndo() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-tests", "--reset-testdata", "--demo"]; app.launch()
        app.buttons["new-match"].tap()
        reveal(app.segmentedControls.buttons["Traditional"], in: app); app.segmentedControls.buttons["Traditional"].tap()
        reveal(app.buttons["start-match"], in: app); app.buttons["start-match"].tap()
        XCTAssertTrue(app.buttons["adjust-0-10"].waitForExistence(timeout: 5))
        app.buttons["adjust-0-10"].tap(); app.buttons["adjust-1-5"].tap()
        XCTAssertEqual(app.staticTexts["score-0"].label, "10"); XCTAssertEqual(app.staticTexts["score-1"].label, "5")
        app.buttons["Finish frame"].tap(); app.buttons["Alex wins the frame"].tap()
        XCTAssertTrue(app.staticTexts["Alex wins the frame"].waitForExistence(timeout: 5))
        app.buttons["undo"].tap()
        XCTAssertEqual(app.staticTexts["current-turn"].label, "Traditional scoreboard")
        XCTAssertEqual(app.staticTexts["score-0"].label, "10")
    }
    @MainActor func testOpenSessionTurnSwitchRedoAndFoulChoices() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-tests","--reset-testdata","--demo"]; app.launch()
        app.buttons["new-match"].tap(); reveal(app.switches["open-session"], in: app); app.switches["open-session"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap(); reveal(app.buttons["start-match"], in: app); app.buttons["start-match"].tap()
        XCTAssertTrue(app.staticTexts["· Open session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ball-1"].isHittable); XCTAssertTrue(app.buttons["end-turn"].isHittable); XCTAssertTrue(app.buttons["redo"].isHittable)
        app.buttons["ball-1"].tap(); app.buttons["undo"].tap(); app.buttons["redo"].tap(); XCTAssertEqual(app.staticTexts["score-0"].label,"1")
        app.buttons["switch-player-1"].tap(); XCTAssertEqual(app.staticTexts["current-turn"].label,"Jamie's turn")
        app.buttons["foul"].tap(); XCTAssertTrue(app.buttons["Pass back"].waitForExistence(timeout: 5)); app.buttons["Pass back"].tap(); app.buttons["record-foul"].tap()
        XCTAssertEqual(app.staticTexts["current-turn"].label,"Jamie's turn"); XCTAssertEqual(app.staticTexts["score-0"].label,"5")
        app.buttons["match-menu"].tap(); app.buttons["Finish frame"].tap(); app.buttons["Alex wins the frame"].tap()
        XCTAssertTrue(app.buttons["Next frame"].waitForExistence(timeout: 5)); app.buttons["Next frame"].tap()
        XCTAssertTrue(app.staticTexts["FRAME 2"].waitForExistence(timeout: 5)); app.buttons["match-menu"].tap(); app.buttons["End session"].tap(); app.buttons["End session and save"].tap()
        XCTAssertTrue(app.staticTexts["Saved to your match history"].waitForExistence(timeout: 5))
        attach(app,"05-open-session-result")
    }
    @MainActor func testPastGameEntryEditUndoRedoAndDelete() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-tests","--reset-testdata","--demo"]; app.launch()
        app.buttons["History"].firstMatch.tap(); app.buttons["add-past-game"].tap(); reveal(app.textFields["past-score-0"], in: app)
        for (p,value) in [(0,"53"),(1,"30")] { let field = app.textFields["past-score-\(p)"]; field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4)+value); if app.buttons["Done"].exists { app.buttons["Done"].tap() } }
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }; reveal(app.buttons["save-past-game"], in: app); app.buttons["save-past-game"].tap()
        app.staticTexts["Alex vs Jamie"].firstMatch.tap()
        app.staticTexts["53–30"].tap(); XCTAssertTrue(app.buttons["edit-frame"].waitForExistence(timeout: 5)); app.buttons["edit-frame"].tap()
        let score = app.textFields["edit-score-0"]; score.tap(); score.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,count:4)+"54")
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }; reveal(app.buttons["save-frame-changes"], in: app); app.buttons["save-frame-changes"].tap()
        XCTAssertTrue(app.staticTexts["54"].waitForExistence(timeout:5)); app.buttons["history-undo"].tap(); XCTAssertTrue(app.staticTexts["53"].exists); app.buttons["history-redo"].tap(); XCTAssertTrue(app.staticTexts["54"].exists)
        attach(app,"06-frame-story")
        app.navigationBars.buttons.element(boundBy:0).tap(); XCTAssertTrue(app.staticTexts["54–30"].exists); app.buttons["delete-match"].tap(); app.buttons["confirm-delete-match"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5)); XCTAssertFalse(app.staticTexts["54–30"].exists)
    }
    @MainActor func testFrameStoryGroupsBallsIntoVisits() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-tests","--reset-testdata","--demo"]; app.launch()
        app.buttons["resume-match"].tap(); app.buttons["match-menu"].tap(); app.buttons["Frame timeline"].tap()
        XCTAssertTrue(app.navigationBars["Frame story"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Red"].firstMatch.exists); XCTAssertTrue(app.staticTexts["Black"].firstMatch.exists)
        XCTAssertTrue(app.buttons["edit-frame"].isHittable); attach(app,"07-ball-by-ball-story")
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 { if element.exists && element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.exists && element.isHittable)
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        // Capture after the native navigation transition, rather than its first visible frame.
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
