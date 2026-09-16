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


extension ChatModel {
    static var preview: ChatModel {
        let model = ChatModel()
        model.state = .online
        model.recipientUserID = "Mika"
        model.ownSafetyNumber = "4821 7750 1904 3382"
        model.recipientSafetyNumbers = ["9550 2711 6842 1290"]
        model.messages = [
            ChatMessage(
                id: "preview-incoming",
                senderUserID: "Mika",
                kind: .text,
                contentType: "text/plain; charset=utf-8",
                data: Data("Bin gleich da 👋".utf8),
                createdAt: Date(timeIntervalSince1970: 1_789_553_100),
                direction: .incoming,
                delivery: .received
            ),
            ChatMessage(
                id: "preview-outgoing",
                senderUserID: "Timo",
                kind: .text,
                contentType: "text/plain; charset=utf-8",
                data: Data("Perfekt, bis gleich.".utf8),
                createdAt: Date(timeIntervalSince1970: 1_789_553_160),
                direction: .outgoing,
                delivery: .received
            )
        ]
        return model
    }
}
