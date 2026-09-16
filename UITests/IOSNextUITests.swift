import XCTest

final class IOSNextUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    @discardableResult
    private func launch(_ screen: String) -> XCUIApplication {
        app?.terminate()
        let application = XCUIApplication()
        application.launchArguments = ["--product-ui-test-screen=\(screen)"]
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

    func testPrimaryProductScreensRender() {
        for screen in ["home", "rooms", "chat", "media", "system", "light", "media-detail", "owner", "wireguard"] {
            let application = launch(screen)
            attachScreenshot("product-\(screen)", app: application)
        }
    }

    func testNativeTabNavigationAndMediaDetail() {
        let application = launch("home")
        let mediaTab = application.tabBars.buttons["Medien"]
        XCTAssertTrue(mediaTab.waitForExistence(timeout: 3))
        XCTAssertTrue(mediaTab.isHittable)
        mediaTab.tap()

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

        let sendButton = application.buttons["Nachricht senden"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 3))
        XCTAssertTrue(sendButton.isHittable)
        attachScreenshot("product-chat-composer", app: application)
    }

    func testLightControlsAreHittableWithoutCallingHomeAssistant() {
        let application = launch("light")
        let power = application.buttons["light-power-button"]
        XCTAssertTrue(power.waitForExistence(timeout: 3))
        XCTAssertTrue(power.isHittable)
        let brightness = application.sliders["light-brightness-slider"]
        XCTAssertTrue(brightness.waitForExistence(timeout: 3))
        XCTAssertTrue(brightness.isHittable)
        attachScreenshot("product-light-detail", app: application)
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
}
