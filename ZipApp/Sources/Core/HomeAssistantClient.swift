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
    case disconnected
    case timeout
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidWebSocketURL: "Die Home-Assistant-URL ist ungültig."
        case .invalidResponse: "Home Assistant hat eine ungültige Antwort gesendet."
        case .disconnected: "Die Home-Assistant-Verbindung wurde getrennt."
        case .timeout: "Home Assistant hat nicht rechtzeitig geantwortet."
        case let .server(message): message
        }
    }
}

actor HomeAssistantClient {
    private var socket: URLSessionWebSocketTask?
    private var messageID = 0
    private var pending: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var receiveTask: Task<Void, Never>?
    private var eventHandler: (@Sendable (HomeAssistantStateChange) async -> Void)?
    private var disconnectHandler: (@Sendable (Error) async -> Void)?
    private var intentionalDisconnect = false
    private var connectionGeneration = 0

    func setEventHandler(_ handler: @escaping @Sendable (HomeAssistantStateChange) async -> Void) {
        eventHandler = handler
    }

    func setDisconnectHandler(_ handler: @escaping @Sendable (Error) async -> Void) {
        disconnectHandler = handler
    }

    func connect(configuration: HomeAssistantConfiguration) async throws -> HomeAssistantSnapshot {
        disconnect()
        intentionalDisconnect = false
        let generation = connectionGeneration
        guard let url = configuration.webSocketURL else { throw HomeAssistantClientError.invalidWebSocketURL }
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

        receiveTask = Task { await receiveLoop(generation: generation) }
        async let states = command(type: "get_states")
        async let areas = command(type: "config/area_registry/list")
        async let devices = command(type: "config/device_registry/list")
        async let registry = command(type: "config/entity_registry/list")
        let (stateResponse, areaResponse, deviceResponse, registryResponse) =
            try await (states, areas, devices, registry)

        guard let stateRows = stateResponse["result"] as? [[String: Any]],
              let areaRows = areaResponse["result"] as? [[String: Any]],
              let deviceRows = deviceResponse["result"] as? [[String: Any]],
              let registryRows = registryResponse["result"] as? [[String: Any]] else {
            throw HomeAssistantClientError.invalidResponse
        }

        _ = try await command(type: "subscribe_events", extra: ["event_type": "state_changed"])
        intentionalDisconnect = false
        return HomeAssistantSnapshot(
            states: stateRows.compactMap(HomeAssistantEntity.init(dictionary:)),
            areas: areaRows.compactMap(HomeAssistantArea.init(dictionary:)),
            devices: deviceRows.compactMap(HomeAssistantDevice.init(dictionary:)),
            entityRegistry: registryRows.compactMap(HomeAssistantRegistryEntity.init(dictionary:))
        )
    }

    func disconnect() {
        intentionalDisconnect = true
        connectionGeneration += 1
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: HomeAssistantClientError.disconnected) }
    }

    func callService(
        domain: String,
        service: String,
        targetEntityID: String,
        serviceData: [String: Any] = [:]
    ) async throws {
        var payload: [String: Any] = [
            "domain": domain,
            "service": service,
            "target": ["entity_id": targetEntityID]
        ]
        if !serviceData.isEmpty {
            payload["service_data"] = serviceData
        }
        _ = try await command(type: "call_service", extra: payload)
    }

    private func command(type: String, extra: [String: Any] = [:]) async throws -> [String: Any] {
        messageID += 1
        let id = messageID
        var payload = extra
        payload["id"] = id
        payload["type"] = type
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            Task {
                do {
                    try await self.send(payload)
                } catch {
                    await self.failCommand(id: id, error: error)
                    return
                }
                try? await Task.sleep(for: .seconds(15))
                await self.timeoutCommand(id: id)
            }
        }
    }

    private func timeoutCommand(id: Int) {
        failCommand(id: id, error: HomeAssistantClientError.timeout)
    }

    private func failCommand(id: Int, error: Error) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(throwing: error)
    }

    private func receiveLoop(generation: Int) async {
        while !Task.isCancelled, generation == connectionGeneration {
            do {
                let response = try await receiveObject()
                await route(response)
            } catch {
                guard generation == connectionGeneration else { return }
                failPending(error)
                if !intentionalDisconnect, let disconnectHandler {
                    await disconnectHandler(error)
                }
                return
            }
        }
    }
    private func route(_ response: [String: Any]) async {
        if let id = response["id"] as? Int, response["type"] as? String == "result" {
            if let continuation = pending.removeValue(forKey: id) {
                do { continuation.resume(returning: try validatedResult(response)) }
                catch { continuation.resume(throwing: error) }
            }
            return
        }

        guard response["type"] as? String == "event",
              let event = response["event"] as? [String: Any],
              event["event_type"] as? String == "state_changed",
              let data = event["data"] as? [String: Any],
              let eventHandler else { return }
        if data["new_state"] is NSNull {
            guard let entityID = data["entity_id"] as? String else { return }
            await eventHandler(.removed(entityID))
            return
        }
        guard let newState = data["new_state"] as? [String: Any],
              let entity = HomeAssistantEntity(dictionary: newState) else { return }
        await eventHandler(.updated(entity))
    }

    private func failPending(_ error: Error) {
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
    }
    private func validatedResult(_ response: [String: Any]) throws -> [String: Any] {
        if response["success"] as? Bool == false {
            throw HomeAssistantClientError.server(errorMessage(from: response))
        }
        return response
    }

    private func errorMessage(from response: [String: Any]) -> String {
        if let error = response["error"] as? [String: Any] {
            return error["message"] as? String ?? "Der Home-Assistant-Aufruf ist fehlgeschlagen."
        }
        return response["error"] as? String ?? "Der Home-Assistant-Aufruf ist fehlgeschlagen."
    }

    private func send(_ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else { throw HomeAssistantClientError.invalidResponse }
        guard let socket else { throw HomeAssistantClientError.disconnected }
        try await socket.send(.string(text))
    }

    private func receiveObject() async throws -> [String: Any] {
        guard let socket else { throw HomeAssistantClientError.disconnected }
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
        guard let entityID = dictionary["entity_id"] as? String,
              let state = dictionary["state"] as? String else { return nil }
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
