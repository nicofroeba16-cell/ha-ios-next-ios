import XCTest

final class ScreenshotUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.activate()
    }

    func testCaptureAllViews() throws {
        XCTAssertTrue(app.staticTexts["Nico"].waitForExistence(timeout: 8))
        capture("01-home")

        for (label, name) in [
            ("Nico-Zimmer", "02-room-nico"),
            ("Timo-Zimmer", "03-room-timo"),
            ("Hütte", "04-room-huette"),
            ("Außenbereich", "05-room-aussen"),
            ("Wohnzimmer", "06-room-wohnzimmer")
        ] {
            tapEnsuringVisible(label, maxSwipes: 5)
            capture(name)
            tapBack()
        }

        tapTab("Räume")
        capture("07-rooms-overview")

        for (label, name) in [
            ("Arbeitszimmer", "08-room-arbeitszimmer"),
            ("Ambiente", "09-room-ambiente"),
            ("Dienst", "10-room-dienst"),
            ("Flur", "11-room-flur"),
            ("Handys", "12-room-handys"),
            ("Juli Zimmer", "13-room-juli"),
            ("Mika Zimmer", "14-room-mika"),
            ("Rasen", "15-room-rasen"),
            ("Tisch", "16-room-tisch")
        ] {
            tapEnsuringVisible(label, maxSwipes: 12)
            capture(name)
            tapBack()
        }

        tapTab("Medien")
        capture("17-media")

        tapTab("Szenen")
        capture("18-scenes")

        tapTab("System")
        capture("19-system")

        tapTab("Zuhause")
        capture("20-home-final")
    }

    private func capture(_ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
}
