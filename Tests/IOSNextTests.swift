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
}
