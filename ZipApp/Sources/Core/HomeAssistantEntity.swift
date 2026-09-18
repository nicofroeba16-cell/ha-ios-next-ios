import Foundation

enum HomeAssistantStateChange: Sendable {
    case updated(HomeAssistantEntity)
    case removed(String)
}

struct HomeAssistantEntity: Identifiable, Hashable, Sendable {
    let entityID: String
    let state: String
    let attributes: [String: JSONValue]

    var id: String { entityID }

    var displayName: String {
        if let preferredPresentationName { return preferredPresentationName }
        if let friendly = attributes["friendly_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !friendly.isEmpty,
           friendly.localizedCaseInsensitiveCompare(entityID) != .orderedSame {
            return friendly
        }
        return presentationFallbackName
    }

    private var preferredPresentationName: String? {
        switch entityID {
        case "light.kronach_kronach": "Licht-Master"
        case "light.kronach_fernseher_links": "TV links"
        case "light.kronach_fernseher_rechts": "TV rechts"
        case "light.kronach_schrank": "Schrank"
        case "switch.schreibtisch_rgb_standlampe_steckdose_1": "Schreibtischlampe"
        case "switch.tv_steckdose_1": "TV-Strom"
        case "media_player.nico_zimmer_untergeschoss_apple_tv": "Apple TV"
        case "media_player.denon_avr_x1300w": "Denon AVR"
        case "media_player.playstation_5": "PlayStation 5"
        case "light.hutte": "Ambiente"
        case "light.tisch_tisch": "Tisch"
        default: nil
        }
    }

    private var presentationFallbackName: String {
        let objectID = entityID.split(separator: ".", maxSplits: 1).dropFirst().first.map(String.init) ?? entityID
        let words = objectID
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { token in
                let text = String(token)
                if text.allSatisfy({ $0.isNumber }) { return text }
                return text.prefix(1).uppercased() + text.dropFirst()
            }
        let candidate = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? domain.localizedCapitalized : candidate
    }

    var isOn: Bool {
        state == "on" || state == "playing"
    }

    var domain: String {
        entityID.split(separator: ".", maxSplits: 1).first.map(String.init) ?? ""
    }

    var areaID: String? { attributes["area_id"]?.stringValue }
    var deviceID: String? { attributes["device_id"]?.stringValue }
    var isAvailable: Bool { state != "unavailable" && state != "unknown" }
    var brightness: Double? { attributes["brightness"]?.numberValue }
    var volumeLevel: Double? { attributes["volume_level"]?.numberValue }
    var isMuted: Bool? { attributes["is_volume_muted"]?.boolValue }
    var mediaTitle: String? { attributes["media_title"]?.stringValue }
    var mediaArtist: String? { attributes["media_artist"]?.stringValue }
    var supportedFeatures: Int {
        Int(attributes["supported_features"]?.numberValue ?? 0)
    }

    var supportsToggle: Bool {
        ["light", "switch", "fan", "input_boolean"].contains(domain)
    }

    var supportsMediaControls: Bool { domain == "media_player" }
    var mediaContentType: String? { attributes["media_content_type"]?.stringValue }
    var mediaImageURL: String? { attributes["entity_picture"]?.stringValue }
    var unitOfMeasurement: String? { attributes["unit_of_measurement"]?.stringValue }
    var currentTemperature: Double? { attributes["current_temperature"]?.numberValue }
    var targetTemperature: Double? { attributes["temperature"]?.numberValue }
    var position: Double? {
        if domain == "cover" { return attributes["current_position"]?.numberValue }
        return nil
    }

    var iconName: String {
        switch domain {
        case "light": "lightbulb.fill"
        case "switch", "input_boolean": "switch.2"
        case "media_player": "play.rectangle.fill"
        case "scene": "circle.hexagongrid.fill"
        case "script": "scroll.fill"
        case "sensor": "gauge.with.dots.needle.50percent"
        case "binary_sensor": "sensor.fill"
        case "climate": "thermometer.medium"
        case "cover": "window.shade.open"
        case "lock": "lock.fill"
        case "fan": "fan.fill"
        default: "circle.grid.2x2.fill"
        }
    }

    var stateDisplayText: String {
        switch state.lowercased() {
        case "on": "Ein"
        case "off": "Aus"
        case "playing": "Wiedergabe"
        case "paused": "Pausiert"
        case "idle": "Bereit"
        case "standby": "Standby"
        case "unknown", "unavailable": "Nicht verfügbar"
        case "problem": "Problem"
        default: state.localizedCapitalized
        }
    }

    var secondaryStateText: String {
        if domain == "media_player", let mediaTitle { return mediaTitle }
        if let unitOfMeasurement { return "\(state) \(unitOfMeasurement)" }
        return stateDisplayText
    }

    var isPrimaryRoomControl: Bool {
        guard [EntityControlKind.toggle, .cover, .climate, .lock].contains(controlKind) else { return false }
        let searchable = "\(entityID) \(displayName)".lowercased()
        let technicalTerms = [
            "wi-fi", "wifi", "wlan", "pre-release", "pre_release", "kindersicherung",
            "automation:", "automatische aktualisierungen", "bluetooth", "cloud", "sprache",
            "safe browsing", "sichere suche", "abfrageprotokoll", "filterung", "jugendschutz"
        ]
        return !technicalTerms.contains { searchable.contains($0) }
    }

    var controlKind: EntityControlKind {
        switch domain {
        case "light": .light
        case "switch", "fan", "input_boolean": .toggle
        case "media_player": .media
        case "cover": .cover
        case "climate": .climate
        case "lock": .lock
        case "scene": .scene
        case "script": .script
        default: .readOnly
        }
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
