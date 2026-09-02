import Foundation

struct HomeAssistantConfiguration: Codable, Equatable {
    let baseURL: URL
    let accessToken: String

    var webSocketURL: URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components?.path = "/api/websocket"
        return components?.url
    }
}

enum HomeAssistantClientError: LocalizedError {
    case invalidWebSocketURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidWebSocketURL: "Die Home-Assistant-URL ist ungültig."
        case .invalidResponse: "Home Assistant hat eine ungültige Antwort gesendet."
        case let .server(message): message
        }
    }
}

actor HomeAssistantClient {
    private var socket: URLSessionWebSocketTask?
    private var messageID = 0

    func connect(configuration: HomeAssistantConfiguration) async throws -> [HomeAssistantEntity] {
        guard let url = configuration.webSocketURL else { throw HomeAssistantClientError.invalidWebSocketURL }
        socket?.cancel(with: .goingAway, reason: nil)
        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()

        let required = try await receiveObject()
        guard required["type"] as? String == "auth_required" else { throw HomeAssistantClientError.invalidResponse }
        try await send(["type": "auth", "access_token": configuration.accessToken])
        let authenticated = try await receiveObject()
        guard authenticated["type"] as? String == "auth_ok" else {
            throw HomeAssistantClientError.server(authenticated["message"] as? String ?? "Anmeldung bei Home Assistant fehlgeschlagen.")
        }

        let states = try await command(type: "get_states")
        guard let rows = states["result"] as? [[String: Any]] else { throw HomeAssistantClientError.invalidResponse }
        return rows.compactMap(HomeAssistantEntity.init(dictionary:))
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    func callService(domain: String, service: String, targetEntityID: String) async throws {
        _ = try await command(type: "call_service", extra: [
            "domain": domain,
            "service": service,
            "target": ["entity_id": targetEntityID]
        ])
    }

    private func command(type: String, extra: [String: Any] = [:]) async throws -> [String: Any] {
        messageID += 1
        var payload = extra
        payload["id"] = messageID
        payload["type"] = type
        try await send(payload)
        while true {
            let response = try await receiveObject()
            if response["id"] as? Int == messageID {
                guard response["success"] as? Bool != false else {
                    throw HomeAssistantClientError.server(response["error"] as? String ?? "Der Home-Assistant-Aufruf ist fehlgeschlagen.")
                }
                return response
            }
        }
    }

    private func send(_ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else { throw HomeAssistantClientError.invalidResponse }
        guard let socket else { throw HomeAssistantClientError.invalidResponse }
        try await socket.send(.string(text))
    }

    private func receiveObject() async throws -> [String: Any] {
        guard let socket else { throw HomeAssistantClientError.invalidResponse }
        let message = try await socket.receive()
        let text: String
        switch message {
        case let .string(value): text = value
        case let .data(data): text = String(decoding: data, as: UTF8.self)
        @unknown default: throw HomeAssistantClientError.invalidResponse
        }
        guard let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            throw HomeAssistantClientError.invalidResponse
        }
        return object
    }
}

private extension HomeAssistantEntity {
    init?(dictionary: [String: Any]) {
        guard let entityID = dictionary["entity_id"] as? String, let state = dictionary["state"] as? String else { return nil }
        let rawAttributes = dictionary["attributes"] as? [String: Any] ?? [:]
        let attributes = rawAttributes.compactMapValues(JSONValue.init(any:))
        self.init(entityID: entityID, state: state, attributes: attributes)
    }
}

private extension JSONValue {
    init?(any: Any) {
        switch any {
        case let value as String: self = .string(value)
        case let value as Bool: self = .bool(value)
        case let value as NSNumber: self = .number(value.doubleValue)
        case let value as [String: Any]: self = .object(value.compactMapValues(JSONValue.init(any:)))
        case let value as [Any]: self = .array(value.compactMap(JSONValue.init(any:)))
        case is NSNull: self = .null
        default: return nil
        }
    }
}
