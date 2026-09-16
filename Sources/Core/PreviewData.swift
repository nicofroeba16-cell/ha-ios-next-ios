import Foundation

extension AppModel {
    static var preview: AppModel {
        let model = AppModel()
        model.connectionState = .connected
        model.entities = [
            .init(
                entityID: "light.hintergrund_fernseher",
                state: "on",
                attributes: ["friendly_name": .string("Hintergrund Fernseher"), "brightness": .number(184)]
            ),
            .init(
                entityID: "light.nachttisch",
                state: "off",
                attributes: ["friendly_name": .string("Nachttisch")]
            ),
            .init(
                entityID: "light.schlafzimmer",
                state: "on",
                attributes: ["friendly_name": .string("Schlafzimmer"), "brightness": .number(122)]
            ),
            .init(
                entityID: "media_player.schlafzimmer",
                state: "playing",
                attributes: [
                    "friendly_name": .string("Schlafzimmer"),
                    "media_title": .string("Abendmix"),
                    "media_artist": .string("Apple Music"),
                    "volume_level": .number(0.34),
                    "media_position": .number(96)
                ]
            ),
            .init(
                entityID: "climate.schlafzimmer",
                state: "heat",
                attributes: [
                    "friendly_name": .string("Heizung"),
                    "temperature": .number(21.5),
                    "current_temperature": .number(20.8)
                ]
            ),
            .init(
                entityID: "scene.abend",
                state: "scening",
                attributes: ["friendly_name": .string("Abend")]
            ),
            .init(
                entityID: "sensor.test_offline",
                state: "unavailable",
                attributes: ["friendly_name": .string("Beispielsensor")]
            )
        ]
        return model
    }
}
