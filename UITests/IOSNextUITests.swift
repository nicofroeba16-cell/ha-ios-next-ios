import XCTest

final class IOSNextUITests: XCTestCase {
    private var app: XCUIApplication!
    private let screens = ["home", "rooms", "chat", "media", "system", "light", "media-detail", "owner", "wireguard"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
        XCUIDevice.shared.orientation = .portrait
    }

    @discardableResult
    private func launch(_ screen: String, extraArguments: [String] = []) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = ["--product-ui-test-screen=\(screen)"] + extraArguments
        application.launch()
        let root = application.descendants(matching: .any)
            .matching(identifier: "product-acceptance-\(screen)")
            .firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 8), "Product screen did not render: \(screen)")
        waitForVisualReady(
            screen,
            dark: extraArguments.contains("--product-ui-test-dark"),
            in: application,
            timeout: 8
        )
        app = application
        return application
    }

    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func switchAcceptanceScreen(
        _ screen: String,
        dark: Bool = false,
        in application: XCUIApplication
    ) {
        let switcher = application.buttons["acceptance-switch-\(screen)"].firstMatch
        XCTAssertTrue(switcher.waitForExistence(timeout: 3))
        XCTAssertTrue(switcher.isHittable)
        switcher.tap()

        let root = application.descendants(matching: .any)
            .matching(identifier: "product-acceptance-\(screen)")
            .firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 5), "Product screen did not settle: \(screen)")
        waitForVisualReady(screen, dark: dark, in: application, timeout: 6)
    }

    private func waitForVisualReady(
        _ screen: String,
        dark: Bool,
        in application: XCUIApplication,
        timeout: TimeInterval
    ) {
        let appearance = dark ? "dark" : "light"
        let probe = application.descendants(matching: .any)
            .matching(identifier: "visual-ready-product-\(screen)-\(appearance)")
            .firstMatch
        XCTAssertTrue(probe.waitForExistence(timeout: timeout), "Visual-ready probe missing: \(screen) \(appearance)")
        let predicate = NSPredicate(format: "value == %@", "ready")
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: probe)],
            timeout: timeout
        )
        XCTAssertEqual(result, .completed, "Visual frame did not settle: \(screen) \(appearance)")
    }

    private func waitForAcceptanceAppearance(dark: Bool, in application: XCUIApplication) {
        let root = application.descendants(matching: .any)
            .matching(identifier: "product-acceptance-home")
            .firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 5))
        let expected = "darkMode=\(dark)"
        let predicate = NSPredicate(format: "value CONTAINS %@", expected)
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: root)],
            timeout: 5
        )
        XCTAssertEqual(result, .completed, "Appearance did not settle to \(expected)")
        waitForVisualReady("home", dark: dark, in: application, timeout: 6)
    }

    private func setOrientation(_ orientation: UIDeviceOrientation, in application: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        let expectsLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        let deadline = Date().addingTimeInterval(6)

        while Date() < deadline {
            let frame = application.windows.firstMatch.frame
            if frame.width > 0, frame.height > 0 {
                let isLandscape = frame.width > frame.height
                if isLandscape == expectsLandscape {
                    return
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTFail("Orientation did not settle: \(orientation.rawValue)")
    }

    private func captureAllProductScreens(
        prefix: String,
        dark: Bool,
        in application: XCUIApplication
    ) {
        for screen in screens {
            switchAcceptanceScreen(screen, dark: dark, in: application)
            attachScreenshot("\(prefix)-\(screen)", app: application)
        }
    }

    func testPrimaryProductScreensRenderLightAndDark() {
        let application = launch("home", extraArguments: ["--product-ui-test-switcher"])
        waitForAcceptanceAppearance(dark: false, in: application)

        captureAllProductScreens(prefix: "product-light", dark: false, in: application)

        switchAcceptanceScreen("home", in: application)
        let appearanceToggle = application.buttons["acceptance-toggle-appearance"].firstMatch
        XCTAssertTrue(appearanceToggle.waitForExistence(timeout: 3))
        XCTAssertTrue(appearanceToggle.isHittable)
        appearanceToggle.tap()
        waitForAcceptanceAppearance(dark: true, in: application)

        captureAllProductScreens(prefix: "product-dark", dark: true, in: application)
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

        let fireTV = application.buttons["media-player-link-media_player.fire_tv_companion"]
        XCTAssertTrue(fireTV.waitForExistence(timeout: 3))
        if !fireTV.isHittable {
            application.swipeUp()
        }
        XCTAssertTrue(fireTV.isHittable)
        fireTV.tap()

        XCTAssertTrue(application.navigationBars["Fire TV Companion"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.buttons["Pause"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.buttons["10 Sekunden zurück"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.buttons["10 Sekunden vor"].waitForExistence(timeout: 3))
        attachScreenshot("product-fire-tv-companion-detail", app: application)
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
        let application = launch("owner", extraArguments: ["--product-ui-test-switcher"])
        XCTAssertTrue(application.staticTexts["Owner-Zugang nicht eingerichtet"].waitForExistence(timeout: 3))
        attachScreenshot("product-owner-entry", app: application)

        switchAcceptanceScreen("wireguard", dark: false, in: application)
        XCTAssertTrue(application.navigationBars["WireGuard"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.staticTexts["iOS Next WireGuard"].waitForExistence(timeout: 3))
        attachScreenshot("product-wireguard-entry", app: application)
    }

    private func accessibilityState(in application: XCUIApplication) -> String {
        let root = application.descendants(matching: .any)
            .matching(identifier: "product-acceptance-home")
            .firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 5))
        return root.value as? String ?? ""
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
        let application = launch("home", extraArguments: ["--product-ui-test-switcher"])
        waitForAcceptanceAppearance(dark: false, in: application)

        setOrientation(.portrait, in: application)
        waitForVisualReady("home", dark: false, in: application, timeout: 6)
        captureAllProductScreens(prefix: "ipad-portrait-light", dark: false, in: application)

        switchAcceptanceScreen("home", dark: false, in: application)
        let appearanceToggle = application.buttons["acceptance-toggle-appearance"].firstMatch
        XCTAssertTrue(appearanceToggle.waitForExistence(timeout: 3))
        XCTAssertTrue(appearanceToggle.isHittable)
        appearanceToggle.tap()
        waitForAcceptanceAppearance(dark: true, in: application)
        captureAllProductScreens(prefix: "ipad-portrait-dark", dark: true, in: application)

        setOrientation(.landscapeLeft, in: application)
        waitForVisualReady("wireguard", dark: true, in: application, timeout: 6)
        captureAllProductScreens(prefix: "ipad-landscape-dark", dark: true, in: application)

        switchAcceptanceScreen("home", dark: true, in: application)
        appearanceToggle.tap()
        waitForAcceptanceAppearance(dark: false, in: application)
        captureAllProductScreens(prefix: "ipad-landscape-light", dark: false, in: application)
    }
}
