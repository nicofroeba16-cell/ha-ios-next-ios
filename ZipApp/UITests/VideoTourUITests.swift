import XCTest

final class VideoTourUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.activate()
    }

    func testRecordAllViews() throws {
        // New Owner home: only stable labels, no exact live-state assertions.
        XCTAssertTrue(app.staticTexts["Nico"].waitForExistence(timeout: 8))
        linger(3.0)

        // Nico hero and room detail.
        tapEnsuringVisible("Nico-Zimmer", maxSwipes: 3); linger(3.0); tapBack(); linger(1.0)

        // Show the main dashboard-inspired cards without relying on state values.
        for label in ["Hütte", "Außenbereich", "Wohnzimmer"] {
            tapEnsuringVisible(label, maxSwipes: 5); linger(2.0); tapBack(); linger(1.0)
        }

        // Full inventory remains reachable.
        tapTab("Räume"); linger(3.0)
        tapTab("Medien"); linger(3.0)
        tapTab("Szenen"); linger(3.0)
        tapTab("System"); linger(3.0)

        // Finish on the redesigned owner home.
        tapTab("Zuhause"); linger(4.0)
    }

    private func tapTab(_ title: String) {
        let button = app.tabBars.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing tab: \(title)")
        button.tap()
    }

    private func tapEnsuringVisible(_ label: String, maxSwipes: Int) {
        for _ in 0...maxSwipes {
            let button = app.buttons[label]
            if button.exists && button.isHittable { button.tap(); return }
            let text = app.staticTexts[label]
            if text.exists && text.isHittable { text.tap(); return }
            app.swipeUp()
        }
        XCTFail("Missing visible UI element: \(label)")
    }

    private func tapBack() {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing back button")
        button.tap()
    }

    private func linger(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
