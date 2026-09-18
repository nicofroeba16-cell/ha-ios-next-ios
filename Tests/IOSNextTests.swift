import XCTest
@testable import IOSNext

final class IOSNextTests: XCTestCase {
    func testProfileHasStableIdentity() {
        XCTAssertEqual(HomeProfile.timo.id, "timo")
    }

    func testEntityOnState() {
        let entity = HomeAssistantEntity(entityID: "light.example", state: "on", attributes: [:])
        XCTAssertTrue(entity.isOn)
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
        guard let url = configuration.authorizationURL else {
            return XCTFail("Authorization URL missing")
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(url.path, "/auth/authorize")
        XCTAssertEqual(items?.first(where: { $0.name == "redirect_uri" })?.value, "iosnext://auth")
    }


    func testEntityDomainAndAvailability() {
        let entity = HomeAssistantEntity(entityID: "media_player.living_room", state: "playing", attributes: [:])
        XCTAssertEqual(entity.domain, "media_player")
        XCTAssertTrue(entity.isAvailable)
        XCTAssertTrue(entity.isOn)
    }

    func testUnavailableEntityIsNotAvailable() {
        let entity = HomeAssistantEntity(entityID: "light.example", state: "unavailable", attributes: [:])
        XCTAssertFalse(entity.isAvailable)
    }

    func testOAuthCredentialRefreshWindow() {
        let configuration = HomeAssistantOAuthConfiguration(
            instanceURL: URL(string: "https://ha.example.com")!,
            clientID: URL(string: "https://example.com/client")!
        )
        let credential = HomeAssistantOAuthCredential(
            configuration: configuration,
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(30)
        )
        XCTAssertTrue(credential.needsRefresh)
    }


    func testEntityCapabilitiesExposeAttributes() {
        let entity = HomeAssistantEntity(
            entityID: "media_player.example",
            state: "playing",
            attributes: [
                "volume_level": .number(0.42),
                "is_volume_muted": .bool(true),
                "media_title": .string("Test Song"),
                "supported_features": .number(123)
            ]
        )
        XCTAssertEqual(entity.volumeLevel, 0.42)
        XCTAssertEqual(entity.isMuted, true)
        XCTAssertEqual(entity.mediaTitle, "Test Song")
        XCTAssertEqual(entity.supportedFeatures, 123)
        XCTAssertTrue(entity.supportsMediaControls)
    }

    func testToggleCapabilityUsesDomain() {
        XCTAssertTrue(HomeAssistantEntity(entityID: "light.test", state: "off", attributes: [:]).supportsToggle)
        XCTAssertFalse(HomeAssistantEntity(entityID: "sensor.test", state: "12", attributes: [:]).supportsToggle)
    }


    func testControlKindsAreDomainSpecific() {
        XCTAssertEqual(entity("light.test").controlKind, .light)
        XCTAssertEqual(entity("cover.test").controlKind, .cover)
        XCTAssertEqual(entity("climate.test").controlKind, .climate)
        XCTAssertEqual(entity("lock.test").controlKind, .lock)
        XCTAssertEqual(entity("sensor.test").controlKind, .readOnly)
    }

    func testSensorSecondaryTextIncludesUnit() {
        let sensor = HomeAssistantEntity(
            entityID: "sensor.temperature",
            state: "21.5",
            attributes: ["unit_of_measurement": .string("°C")]
        )
        XCTAssertEqual(sensor.secondaryStateText, "21.5 °C")
    }

    func testJSONValueRoundTrip() throws {
        let original: JSONValue = .object([
            "name": .string("Lamp"),
            "level": .number(42),
            "active": .bool(true),
            "items": .array([.null, .string("x")])
        ])
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), original)
    }


    func testOAuthAuthorizationURLCarriesState() {
        let configuration = HomeAssistantOAuthConfiguration(
            instanceURL: URL(string: "https://ha.example.com")!,
            clientID: URL(string: "https://example.com/ios-next")!
        )
        guard let url = configuration.authorizationURL(state: "nonce-123") else {
            return XCTFail("Authorization URL missing")
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.first(where: { $0.name == "state" })?.value, "nonce-123")
    }


    func testControlKindsCoverActions() {
        XCTAssertEqual(entity("media_player.test").controlKind, .media)
        XCTAssertEqual(entity("scene.test").controlKind, .scene)
        XCTAssertEqual(entity("script.test").controlKind, .script)
        XCTAssertEqual(entity("fan.test").controlKind, .toggle)
    }

    func testCoverPositionAttribute() {
        let cover = HomeAssistantEntity(
            entityID: "cover.blind",
            state: "open",
            attributes: ["current_position": .number(67)]
        )
        XCTAssertEqual(cover.position, 67)
    }


    func testUnavailableStateTextTakesPriorityOverUnit() {
        let sensor = HomeAssistantEntity(
            entityID: "sensor.temperature",
            state: "unavailable",
            attributes: ["unit_of_measurement": .string("°C")]
        )
        XCTAssertEqual(sensor.secondaryStateText, "Unavailable")
    }

    func testMediaTitleBecomesSecondaryState() {
        let player = HomeAssistantEntity(
            entityID: "media_player.test",
            state: "playing",
            attributes: ["media_title": .string("Track")]
        )
        XCTAssertEqual(player.secondaryStateText, "Track")
    }


    func testAreaRegistryDecoding() {
        let area = HomeAssistantArea(dictionary: [
            "area_id": "nico_zimmer_untergeschoss",
            "name": "Nico Zimmer"
        ])
        XCTAssertEqual(area?.id, "nico_zimmer_untergeschoss")
        XCTAssertEqual(area?.name, "Nico Zimmer")
    }

    func testDeviceRegistryPrefersUserName() {
        let device = HomeAssistantDevice(dictionary: [
            "id": "device-1",
            "name": "Original",
            "name_by_user": "Wohnzimmer TV",
            "area_id": "wohnzimmer"
        ])
        XCTAssertEqual(device?.name, "Wohnzimmer TV")
        XCTAssertEqual(device?.areaID, "wohnzimmer")
    }

    func testEntityRegistryPreservesDeviceAndAreaLinks() {
        let registry = HomeAssistantRegistryEntity(dictionary: [
            "entity_id": "light.test",
            "device_id": "device-1",
            "area_id": "wohnzimmer"
        ])
        XCTAssertEqual(registry?.entityID, "light.test")
        XCTAssertEqual(registry?.deviceID, "device-1")
        XCTAssertEqual(registry?.areaID, "wohnzimmer")
    }

    func testProductionOAuthClientIDUsesPublishedPage() {
        XCTAssertEqual(
            HomeAssistantOAuthConfiguration.productionClientID.absoluteString,
            "https://nicofroeba16-cell.github.io/ha-ios-next-ios/"
        )
    }

    private func entity(_ id: String) -> HomeAssistantEntity {
        HomeAssistantEntity(entityID: id, state: "off", attributes: [:])
    }
}
