import Foundation

extension AppModel {
    static var preview: AppModel {
        let model = AppModel()
        model.connectionState = .connected
        model.entities = [
            .init(entityID: "light.hintergrund_fernseher", state: "on", attributes: ["friendly_name": .string("Hintergrund Fernseher")]),
            .init(entityID: "light.nachttisch", state: "off", attributes: ["friendly_name": .string("Nachttisch")]),
            .init(entityID: "media_player.schlafzimmer", state: "playing", attributes: ["friendly_name": .string("Schlafzimmer")])
        ]
        return model
    }
}
