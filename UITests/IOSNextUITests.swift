import XCTest

final class IOSNextUITests: XCTestCase {
    private var app: XCUIApplication!
    private let screens = ["home", "rooms", "chat", "media", "system", "light", "media-detail", "owner", "wireguard"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        XCUIDevice.shared.orientation = .portrait
    }

    @discardableResult
    private func launch(_ screen: String, extraArguments: [String] = []) -> XCUIApplication {
        app?.terminate()
        let application = XCUIApplication()
        application.launchArguments = ["--product-ui-test-screen=\(screen)"] + extraArguments
        application.launch()
        let root = application.descendants(matching: .any)
            .matching(identifier: "product-acceptance-\(screen)")
            .firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 8), "Product screen did not render: \(screen)")
        app = application
        return application
    }

    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPrimaryProductScreensRenderLightAndDark() {
        for (style, arguments) in [
            ("light", []),
            ("dark", ["--product-ui-test-dark"])
        ] {
            for screen in screens {
                let application = launch(screen, extraArguments: arguments)
                attachScreenshot("product-\(style)-\(screen)", app: application)
            }
        }
    }

    func testNativeTabNavigationAndMediaDetail() throws {
        let application = launch("home")
        if application.tabBars.buttons["Medien"].waitForExistence(timeout: 2) {
            let mediaTab = application.tabBars.buttons["Medien"]
            XCTAssertTrue(mediaTab.isHittable)
            mediaTab.tap()
        } else {
            let mediaRow = application.descendants(matching: .any)
                .matching(identifier: "app-tab-media")
                .firstMatch
            guard mediaRow.waitForExistence(timeout: 2) else {
                throw XCTSkip("Adaptive media navigation control not available on this device.")
            }
            mediaRow.tap()
        }

        XCTAssertTrue(application.navigationBars["Medien"].waitForExistence(timeout: 3))
        let nowPlaying = application.buttons["media-player-link-media_player.schlafzimmer"]
        XCTAssertTrue(nowPlaying.waitForExistence(timeout: 3))
        XCTAssertTrue(nowPlaying.isHittable)
        nowPlaying.tap()

        XCTAssertTrue(application.navigationBars["Schlafzimmer"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.buttons["Pause"].waitForExistence(timeout: 3))
        attachScreenshot("product-media-detail-interaction", app: application)
    }

    func testChatComposerInteraction() {
        let application = launch("chat")
        let field = application.textFields["chat-composer-field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertTrue(field.isHittable)
        field.tap()
        field.typeText("Hallo aus XCUITest")
        XCTAssertEqual(field.value as? String, "Hallo aus XCUITest")

        let sendButton = application.buttons["Nachricht senden"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 3))
        XCTAssertTrue(sendButton.isHittable)
        attachScreenshot("product-chat-composer", app: application)
    }

    func testLightSliderInteraction() {
        let application = launch("light")
        let power = application.buttons["light-power-button"]
        XCTAssertTrue(power.waitForExistence(timeout: 3))
        XCTAssertTrue(power.isHittable)

        let brightness = application.sliders["light-brightness-slider"]
        XCTAssertTrue(brightness.waitForExistence(timeout: 3))
        XCTAssertTrue(brightness.isHittable)
        let before = brightness.value as? String
        brightness.adjust(toNormalizedSliderPosition: 0.28)
        let after = brightness.value as? String
        XCTAssertNotEqual(before, after)
        attachScreenshot("product-light-slider-interaction", app: application)
    }

    func testOwnerAndWireGuardSafeEntryStates() {
        var application = launch("owner")
        XCTAssertTrue(application.staticTexts["Owner-Zugang nicht eingerichtet"].waitForExistence(timeout: 3))
        attachScreenshot("product-owner-entry", app: application)

        application = launch("wireguard")
        XCTAssertTrue(application.navigationBars["WireGuard"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.staticTexts["iOS Next WireGuard"].waitForExistence(timeout: 3))
        attachScreenshot("product-wireguard-entry", app: application)
    }

    private func accessibilityState(in application: XCUIApplication) -> String {
        let probe = application.staticTexts["accessibility-state-probe"].firstMatch
        XCTAssertTrue(probe.waitForExistence(timeout: 3))
        return probe.value as? String ?? ""
    }

    func testAccessibilityCoreScreenRenders() {
        let application = launch("home")
        XCTAssertTrue(application.staticTexts["Favoriten"].waitForExistence(timeout: 3))
        _ = accessibilityState(in: application)
        attachScreenshot("product-accessibility-current-system-settings", app: application)
    }

    func testDynamicTypeAccessibilityState() {
        let application = launch("home")
        XCTAssertTrue(accessibilityState(in: application).contains("dynamicTypeAccessibility=true"))
        attachScreenshot("product-accessibility-dynamic-type-xxxl", app: application)
    }

    func testReduceMotionAccessibilityState() {
        let application = launch("home")
        XCTAssertTrue(accessibilityState(in: application).contains("reduceMotion=true"))
        attachScreenshot("product-accessibility-reduce-motion", app: application)
    }

    func testReduceTransparencyAccessibilityState() {
        let application = launch("home")
        XCTAssertTrue(accessibilityState(in: application).contains("reduceTransparency=true"))
        attachScreenshot("product-accessibility-reduce-transparency", app: application)
    }

    func testIncreaseContrastAccessibilityState() {
        let application = launch("home")
        XCTAssertTrue(accessibilityState(in: application).contains("increasedContrast=true"))
        attachScreenshot("product-accessibility-increase-contrast", app: application)
    }

    func testIPadPortraitLandscapeCoreScreens() {
        XCUIDevice.shared.orientation = .portrait
        for screen in ["home", "media", "system"] {
            let application = launch(screen)
            attachScreenshot("ipad-portrait-\(screen)", app: application)
        }

        XCUIDevice.shared.orientation = .landscapeLeft
        for screen in ["home", "media", "system"] {
            let application = launch(screen, extraArguments: ["--product-ui-test-dark"])
            attachScreenshot("ipad-landscape-dark-\(screen)", app: application)
        }
    }
}
