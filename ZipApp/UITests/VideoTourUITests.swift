import XCTest

final class VideoTourUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.activate()
    }

    func testRecordAllViews() throws {
        // Zuhause: Live-HA fixture overview
        linger(2.0)

        // Räume: use a real area from the live registry, no demo entity names.
        tapTab("Räume"); linger(2.0)
        tapEnsuringVisible("Timo Zimmer", maxSwipes: 16); linger(3.0); tapBack(); linger(1.0)

        // Media/scenes overview from the complete fixture.
        tapTab("Medien"); linger(3.0)
        tapTab("Szenen"); linger(3.0)

        // System inventory views ensure all live entities remain reachable.
        tapTab("System"); linger(2.0)
        openSystemInventory("Alle Entitäten")
        openSystemInventory("Aktionen & Dienste")
        openSystemInventory("Entitäten ohne Raum")

        // Connection sheet is another app view, but do not disconnect fixture data.
        tapEnsuringVisible("Verbindung verwalten")
        linger(3.0)
        closeSetup(); linger(2.0)
    }

    private func tapTab(_ title: String) {
        let button = app.tabBars.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing tab: \(title)")
        button.tap()
    }

    private func tap(_ label: String) {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 2) { button.tap(); return }
        let text = app.staticTexts[label]
        XCTAssertTrue(text.waitForExistence(timeout: 5), "Missing UI element: \(label)")
        text.tap()
    }

    private func tapEnsuringVisible(_ label: String, maxSwipes: Int = 10) {
        for _ in 0..<maxSwipes {
            let button = app.buttons[label]
            if button.exists && button.isHittable { button.tap(); return }
            let text = app.staticTexts[label]
            if text.exists && text.isHittable { text.tap(); return }
            app.swipeUp()
        }
        XCTFail("Missing/hittable UI element: \(label)")
    }

    private func openAndBack(_ label: String, linger duration: TimeInterval) {
        tap(label); linger(duration); tapBack(); linger(1.0)
    }

    private func openSystemInventory(_ label: String) {
        tapEnsuringVisible(label); linger(3.0); tapBack(); linger(1.0)
    }

    private func tapBack() {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing back button")
        button.tap()
    }

    private func closeSetup() {
        let button = app.buttons["Abbrechen"]
        if button.waitForExistence(timeout: 3) { button.tap() }
    }

    private func linger(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
