import Foundation

struct HomeAssistantArea: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

struct HomeAssistantDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let areaID: String?
}

struct HomeAssistantRegistryEntity: Identifiable, Hashable, Sendable {
    let entityID: String
    let deviceID: String?
    let areaID: String?

    var id: String { entityID }
}

struct HomeAssistantSnapshot: Sendable {
    let states: [HomeAssistantEntity]
    let areas: [HomeAssistantArea]
    let devices: [HomeAssistantDevice]
    let entityRegistry: [HomeAssistantRegistryEntity]
}
extension HomeAssistantArea {
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["area_id"] as? String,
              let name = dictionary["name"] as? String else { return nil }
        self.init(id: id, name: name)
    }
}

extension HomeAssistantDevice {
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String else { return nil }
        let name = dictionary["name_by_user"] as? String
            ?? dictionary["name"] as? String
            ?? id
        self.init(id: id, name: name, areaID: dictionary["area_id"] as? String)
    }
}

extension HomeAssistantRegistryEntity {
    init?(dictionary: [String: Any]) {
        guard let entityID = dictionary["entity_id"] as? String else { return nil }
        self.init(
            entityID: entityID,
            deviceID: dictionary["device_id"] as? String,
            areaID: dictionary["area_id"] as? String
        )
    }
}
