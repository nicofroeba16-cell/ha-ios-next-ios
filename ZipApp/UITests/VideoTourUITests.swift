import XCTest

final class VideoTourUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--video-demo"]
        app.launch()
    }

    func testRecordAllPages() throws {
        linger(2.0)
        openAndBack("Hintergrund Fernseher", linger: 2.0)
        tapTab("Räume"); linger(2.0)
        tap("Timo Zimmer"); linger(2.0)
        openAndBack("Hintergrund Fernseher", linger: 2.0)
        tapBack(); linger(1.0)
        tapTab("Medien"); linger(2.0)
        openAndBack("Schlafzimmer", linger: 3.0)
        tapTab("Szenen"); linger(3.0)
        tapTab("System"); linger(2.0)
        tap("Verbindung verwalten"); linger(3.0)
        closeSetup(); linger(1.5)
        tap("Verbindung entfernen"); linger(3.0)
        tap("Home Assistant verbinden"); linger(3.0)
        closeSetup(); linger(2.0)
    }

    private func tapTab(_ title: String) {
        let b = app.tabBars.buttons[title]
        XCTAssertTrue(b.waitForExistence(timeout: 5), "Missing tab: \(title)")
        b.tap()
    }
    private func tap(_ label: String) {
        let b = app.buttons[label]
        if b.waitForExistence(timeout: 2) { b.tap(); return }
        let t = app.staticTexts[label]
        XCTAssertTrue(t.waitForExistence(timeout: 5), "Missing UI element: \(label)")
        t.tap()
    }
    private func openAndBack(_ label: String, linger duration: TimeInterval) {
        tap(label); linger(duration); tapBack(); linger(1.0)
    }
    private func tapBack() {
        let b = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(b.waitForExistence(timeout: 5), "Missing back button")
        b.tap()
    }
    private func closeSetup() {
        let b = app.buttons["Abbrechen"]
        if b.waitForExistence(timeout: 3) { b.tap() }
    }
    private func linger(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
