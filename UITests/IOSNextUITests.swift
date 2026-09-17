import CoreGraphics
import XCTest
import UIKit

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
        var accepted: XCUIScreenshot?

        for attempt in 1...4 {
            let screenshot = app.screenshot()
            if isValidVisualScreenshot(screenshot) {
                accepted = screenshot
                break
            }

            if attempt < 4 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            }
        }

        guard let screenshot = accepted else {
            XCTFail("Screenshot remained blank/flat after retries: \(name)")
            return
        }

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func isValidVisualScreenshot(_ screenshot: XCUIScreenshot) -> Bool {
        guard let source = UIImage(data: screenshot.pngRepresentation)?.cgImage else {
            return false
        }

        let sampleWidth = 80
        let aspect = Double(source.height) / Double(max(source.width, 1))
        let sampleHeight = max(80, min(180, Int((Double(sampleWidth) * aspect).rounded())))
        let bytesPerRow = sampleWidth * 4
        var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }

        context.interpolationQuality = .low
        context.draw(source, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var count = 0
        var sum = 0.0
        var sumSquares = 0.0
        var nearBlack = 0
        var nearWhite = 0
        var minLuma = 1.0
        var maxLuma = 0.0

        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[offset]) / 255.0
            let g = Double(pixels[offset + 1]) / 255.0
            let b = Double(pixels[offset + 2]) / 255.0
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b

            count += 1
            sum += luma
            sumSquares += luma * luma
            minLuma = min(minLuma, luma)
            maxLuma = max(maxLuma, luma)
            if luma < 0.02 { nearBlack += 1 }
            if luma > 0.98 { nearWhite += 1 }
        }

        guard count > 0 else { return false }

        let mean = sum / Double(count)
        let variance = max(0, sumSquares / Double(count) - mean * mean)
        let deviation = sqrt(variance)
        let blackRatio = Double(nearBlack) / Double(count)
        let whiteRatio = Double(nearWhite) / Double(count)
        let dynamicRange = maxLuma - minLuma

        let blank = mean < 0.015 || mean > 0.985
        let flat = deviation < 0.025 || dynamicRange < 0.12
        let dominated = (blackRatio > 0.985 || whiteRatio > 0.985) && deviation < 0.07

        return !(blank || flat || dominated)
    }

    private func tapWhenVisible(
        _ element: XCUIElement,
        in application: XCUIApplication,
        label: String,
        timeout: TimeInterval = 4
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(label) did not exist")

        let hittable = NSPredicate(format: "hittable == true")
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: hittable, object: element)],
            timeout: timeout
        )
        if result == .completed {
            element.tap()
            return
        }

        let window = application.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 2), "Application window did not exist")
        let visibleFrame = element.frame.intersection(window.frame)
        XCTAssertFalse(
            visibleFrame.isNull || visibleFrame.isEmpty,
            "\(label) exists but is outside the visible application window"
        )
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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

    private func setOrientation(_ orientation: UIDeviceOrientation, in application: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        let expectsLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        let deadline = Date().addingTimeInterval(6)
        var lastFrame = CGRect.zero
        var stableSamples = 0

        while Date() < deadline {
            let frame = application.windows.firstMatch.frame
            if frame.width > 0, frame.height > 0 {
                let isLandscape = frame.width > frame.height
                let sameSize = abs(frame.width - lastFrame.width) < 0.5
                    && abs(frame.height - lastFrame.height) < 0.5

                if isLandscape == expectsLandscape {
                    stableSamples = sameSize ? stableSamples + 1 : 1
                    if stableSamples >= 4 {
                        return
                    }
                } else {
                    stableSamples = 0
                }

                lastFrame = frame
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTFail("Orientation did not settle: \(orientation.rawValue)")
    }

    private func captureAllProductScreens(
        prefix: String,
        dark: Bool,
        orientation: UIDeviceOrientation? = nil
    ) {
        for screen in screens {
            let arguments = dark ? ["--product-ui-test-dark"] : []
            let application = launch(screen, extraArguments: arguments)

            if let orientation {
                setOrientation(orientation, in: application)
                waitForVisualReady(screen, dark: dark, in: application, timeout: 6)
            }

            attachScreenshot("\(prefix)-\(screen)", app: application)
        }
    }

    func testPrimaryProductScreensRenderLightAndDark() {
        captureAllProductScreens(prefix: "product-light", dark: false)
        captureAllProductScreens(prefix: "product-dark", dark: true)
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

        let fireTV = application.buttons["media-player-link-media_player.fire_tv_companion"]
        XCTAssertTrue(
            fireTV.waitForExistence(timeout: 5),
            "Media tab did not expose the expected Fire TV content"
        )
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
        tapWhenVisible(field, in: application, label: "Chat composer")
        application.typeText("Hallo aus XCUITest")
        XCTAssertEqual(field.value as? String, "Hallo aus XCUITest")

        let sendButton = application.buttons["Nachricht senden"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 3))
        XCTAssertTrue(sendButton.isEnabled)
        attachScreenshot("product-chat-composer", app: application)
    }

    func testLightSliderInteraction() {
        let application = launch("light")
        let power = application.buttons["light-power-button"]
        XCTAssertTrue(power.waitForExistence(timeout: 3))
        XCTAssertTrue(power.isEnabled)

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
        let ownerApplication = launch("owner")
        XCTAssertTrue(ownerApplication.staticTexts["Owner-Zugang nicht eingerichtet"].waitForExistence(timeout: 3))
        attachScreenshot("product-owner-entry", app: ownerApplication)

        let wireGuardApplication = launch("wireguard")
        XCTAssertTrue(wireGuardApplication.navigationBars["WireGuard"].waitForExistence(timeout: 3))
        XCTAssertTrue(wireGuardApplication.staticTexts["iOS Next WireGuard"].waitForExistence(timeout: 3))
        attachScreenshot("product-wireguard-entry", app: wireGuardApplication)
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
        captureAllProductScreens(prefix: "ipad-portrait-light", dark: false, orientation: .portrait)
        captureAllProductScreens(prefix: "ipad-portrait-dark", dark: true, orientation: .portrait)
        captureAllProductScreens(prefix: "ipad-landscape-dark", dark: true, orientation: .landscapeLeft)
        captureAllProductScreens(prefix: "ipad-landscape-light", dark: false, orientation: .landscapeLeft)
    }
}
