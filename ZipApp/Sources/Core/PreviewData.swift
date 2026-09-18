import Foundation

private struct LiveHAFixture: Decodable {
    let areas: [Area]
    let devices: [Device]
    let entities: [Entity]

    struct Area: Decodable { let id: String; let name: String }
    struct Device: Decodable { let id: String; let name: String; let areaID: String?; let disabled: Bool }
    struct Entity: Decodable {
        let entityID: String
        let deviceID: String?
        let areaID: String?
        let state: String
        let attributes: [String: JSONValue]
        let disabled: Bool
        let hidden: Bool
        let platform: String?
    }
}

extension AppModel {
    static var preview: AppModel {
        let model = AppModel()
        model.connectionState = .connected
        guard let url = Bundle.main.url(forResource: "live_ha_fixture", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let fixture = try? JSONDecoder().decode(LiveHAFixture.self, from: data) else {
            return fallbackPreview(model)
        }
        model.areas = fixture.areas.map { .init(id: $0.id, name: $0.name) }
        model.devices = fixture.devices.map { .init(id: $0.id, name: $0.name, areaID: $0.areaID) }
        model.entityRegistry = fixture.entities.map {
            .init(entityID: $0.entityID, deviceID: $0.deviceID, areaID: $0.areaID)
        }
        model.entities = fixture.entities.map {
            .init(entityID: $0.entityID, state: $0.state, attributes: $0.attributes)
        }
        return model
    }

    private static func fallbackPreview(_ model: AppModel) -> AppModel {
        model.entities = [.init(entityID: "sensor.fixture_error", state: "unavailable", attributes: ["friendly_name": .string("Live-HA-Fixture nicht geladen")])]
        return model
    }
}
