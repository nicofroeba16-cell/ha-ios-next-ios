import Foundation

extension AppModel {
    static var preview: AppModel {
        let model = AppModel()
        model.connectionState = .connected
        model.entities = [
            .init(
                entityID: "light.hintergrund_fernseher",
                state: "on",
                attributes: ["friendly_name": .string("Hintergrund Fernseher"), "brightness": .number(180)]
            ),
            .init(entityID: "light.nachttisch", state: "off", attributes: ["friendly_name": .string("Nachttisch")]),
            .init(
                entityID: "media_player.schlafzimmer",
                state: "playing",
                attributes: [
                    "friendly_name": .string("Schlafzimmer"),
                    "media_title": .string("Beispieltitel"),
                    "volume_level": .number(0.35)
                ]
            )
        ]
        model.areas = [.init(id: "timo_zimmer", name: "Timo Zimmer")]
        model.devices = [
            .init(id: "light-device", name: "Licht", areaID: "timo_zimmer"),
            .init(id: "media-device", name: "Medienplayer", areaID: "timo_zimmer")
        ]
        model.entityRegistry = [
            .init(entityID: "light.hintergrund_fernseher", deviceID: "light-device", areaID: nil),
            .init(entityID: "light.nachttisch", deviceID: "light-device", areaID: nil),
            .init(entityID: "media_player.schlafzimmer", deviceID: "media-device", areaID: nil)
        ]
        return model
    }
}
