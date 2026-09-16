import Foundation

struct HomeAssistantEntity: Identifiable, Hashable, Sendable {
    let entityID: String
    let state: String
    let attributes: [String: JSONValue]

    var id: String { entityID }

    var displayName: String {
        attributes["friendly_name"]?.stringValue ?? entityID
    }

    var isOn: Bool {
        ["on", "playing", "open", "opening", "heat", "cool"].contains(state)
    }

    var domain: String {
        entityID.split(separator: ".", maxSplits: 1).first.map(String.init) ?? ""
    }

    var stateDisplayName: String {
        switch state {
        case "on": "An"
        case "off": "Aus"
        case "playing": "Wiedergabe"
        case "paused": "Pausiert"
        case "idle": "Bereit"
        case "unavailable": "Nicht verfügbar"
        case "unknown": "Unbekannt"
        case "open": "Geöffnet"
        case "closed": "Geschlossen"
        case "opening": "Öffnet"
        case "closing": "Schließt"
        default: state.localizedCapitalized
        }
    }

    var isAvailable: Bool {
        state != "unavailable" && state != "unknown"
    }

    var brightness: Double? {
        attributes["brightness"]?.numberValue.map { min(max($0 / 255, 0), 1) }
    }

    var volumeLevel: Double? {
        attributes["volume_level"]?.numberValue.map { min(max($0, 0), 1) }
    }

    var mediaTitle: String? { attributes["media_title"]?.stringValue }
    var mediaArtist: String? { attributes["media_artist"]?.stringValue }
    var mediaContentType: String? { attributes["media_content_type"]?.stringValue }
    var source: String? { attributes["source"]?.stringValue }
    var temperature: Double? { attributes["temperature"]?.numberValue }
    var currentTemperature: Double? { attributes["current_temperature"]?.numberValue }
    var currentPosition: Double? { attributes["current_position"]?.numberValue }
    var unitOfMeasurement: String? { attributes["unit_of_measurement"]?.stringValue }
    var supportedFeatures: Int { Int(attributes["supported_features"]?.numberValue ?? 0) }

    func supports(_ feature: Int) -> Bool {
        supportedFeatures & feature == feature
    }

    func updating(state: String) -> HomeAssistantEntity {
        HomeAssistantEntity(entityID: entityID, state: state, attributes: attributes)
    }
}

enum JSONValue: Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }

    var foundationValue: Any {
        switch self {
        case let .string(value): value
        case let .number(value): value
        case let .bool(value): value
        case let .object(value): value.mapValues(\.foundationValue)
        case let .array(value): value.map(\.foundationValue)
        case .null: NSNull()
        }
    }
}

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
