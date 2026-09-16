import Foundation

struct HomeAssistantConfiguration: Codable, Equatable, Sendable {
    let baseURL: URL
    let accessToken: String

    var webSocketURL: URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components?.path = "/api/websocket"
        return components?.url
    }
}

struct HomeAssistantStateChange: Sendable {
    let entityID: String
    let newState: HomeAssistantEntity?
}

enum HomeAssistantClientError: LocalizedError {
    case invalidWebSocketURL
    case invalidResponse
    case disconnected
    case timedOut
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidWebSocketURL: "Die Home-Assistant-URL ist ungültig."
        case .invalidResponse: "Home Assistant hat eine ungültige Antwort gesendet."
        case .disconnected: "Die Verbindung zu Home Assistant wurde getrennt."
        case .timedOut: "Home Assistant hat nicht rechtzeitig geantwortet."
        case let .server(message): message
        }
    }
}

struct HomeAssistantClientTimingPolicy: Sendable {
    let authHandshakeSeconds: Double
    let getStatesSeconds: Double
    let commandSeconds: Double
    let heartbeatIntervalSeconds: Double
    let pingTimeoutSeconds: Double

    static let production = HomeAssistantClientTimingPolicy(
        authHandshakeSeconds: 12,
        getStatesSeconds: 15,
        commandSeconds: 10,
        heartbeatIntervalSeconds: 20,
        pingTimeoutSeconds: 5
    )

    static let integrationTest = HomeAssistantClientTimingPolicy(
        authHandshakeSeconds: 0.45,
        getStatesSeconds: 0.45,
        commandSeconds: 0.45,
        heartbeatIntervalSeconds: 0.20,
        pingTimeoutSeconds: 0.25
    )

    func commandTimeoutSeconds(for type: String) -> Double {
        type == "get_states" ? getStatesSeconds : commandSeconds
    }
}

actor HomeAssistantClient {
    private typealias Response = [String: JSONValue]
    private typealias ResponseContinuation = CheckedContinuation<Response, Error>

    private struct PendingRequest {
        let continuation: ResponseContinuation
        let timeoutTask: Task<Void, Never>
    }

    private let timing: HomeAssistantClientTimingPolicy
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var pendingRequests: [Int: PendingRequest] = [:]
    private var messageID = 0
    private var generation = 0
    private var stateContinuation: AsyncStream<HomeAssistantStateChange>.Continuation?
    private var stateStream: AsyncStream<HomeAssistantStateChange>?

    init(timing: HomeAssistantClientTimingPolicy = .production) {
        self.timing = timing
    }

    func connect(configuration: HomeAssistantConfiguration) async throws -> [HomeAssistantEntity] {
        disconnect()
        guard let url = configuration.webSocketURL else {
            throw HomeAssistantClientError.invalidWebSocketURL
        }

        generation += 1
        let activeGeneration = generation
        let task = URLSession.shared.webSocketTask(with: url)
        task.maximumMessageSize = 8 * 1024 * 1024
        socket = task
        task.resume()

        do {
            let required = try await receiveObject(
                from: task,
                timeoutSeconds: timing.authHandshakeSeconds
            )
            guard required["type"]?.stringValue == "auth_required" else {
                throw HomeAssistantClientError.invalidResponse
            }
            try await send([
                "type": .string("auth"),
                "access_token": .string(configuration.accessToken)
            ], through: task)

            let authenticated = try await receiveObject(
                from: task,
                timeoutSeconds: timing.authHandshakeSeconds
            )
            guard authenticated["type"]?.stringValue == "auth_ok" else {
                throw HomeAssistantClientError.server(
                    authenticated["message"]?.stringValue ?? "Anmeldung bei Home Assistant fehlgeschlagen."
                )
            }

            let streamPair = AsyncStream.makeStream(
                of: HomeAssistantStateChange.self,
                bufferingPolicy: .bufferingNewest(512)
            )
            stateStream = streamPair.stream
            stateContinuation = streamPair.continuation
            receiveTask = Task { [weak self] in
                guard let self else { return }
                await self.receiveLoop(task: task, generation: activeGeneration)
            }
            heartbeatTask = Task { [weak self] in
                guard let self else { return }
                await self.heartbeatLoop(task: task, generation: activeGeneration)
            }

            let statesResponse = try await command(type: "get_states")
            guard let rows = statesResponse["result"]?.arrayValue else {
                throw HomeAssistantClientError.invalidResponse
            }
            let states = rows.compactMap { value -> HomeAssistantEntity? in
                guard case let .object(object) = value else { return nil }
                return HomeAssistantEntity(object: object)
            }

            _ = try await command(
                type: "subscribe_events",
                extra: ["event_type": .string("state_changed")]
            )
            return states
        } catch {
            failConnection(error, generation: activeGeneration)
            throw error
        }
    }

    func stateChanges() -> AsyncStream<HomeAssistantStateChange> {
        stateStream ?? AsyncStream { continuation in continuation.finish() }
    }

    func disconnect() {
        generation += 1
        receiveTask?.cancel()
        receiveTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        finishConnection(with: HomeAssistantClientError.disconnected)
    }

    func callService(
        domain: String,
        service: String,
        targetEntityID: String,
        serviceData: [String: JSONValue] = [:]
    ) async throws {
        _ = try await command(type: "call_service", extra: [
            "domain": .string(domain),
            "service": .string(service),
            "target": .object(["entity_id": .string(targetEntityID)]),
            "service_data": .object(serviceData)
        ])
    }

    nonisolated static func commandTimeoutSeconds(for type: String) -> Double {
        HomeAssistantClientTimingPolicy.production.commandTimeoutSeconds(for: type)
    }

    private func command(type: String, extra: Response = [:]) async throws -> Response {
        guard let socket else { throw HomeAssistantClientError.disconnected }
        messageID += 1
        let requestID = messageID
        var payload = extra
        payload["id"] = .number(Double(requestID))
        payload["type"] = .string(type)
        let timeoutSeconds = timing.commandTimeoutSeconds(for: type)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(timeoutSeconds))
                    guard !Task.isCancelled else { return }
                    await self?.failRequest(requestID, error: HomeAssistantClientError.timedOut)
                }
                pendingRequests[requestID] = PendingRequest(
                    continuation: continuation,
                    timeoutTask: timeoutTask
                )
                Task { [weak self] in
                    do {
                        try await self?.send(payload, through: socket)
                    } catch {
                        await self?.failRequest(requestID, error: error)
                    }
                }
            }
        } onCancel: {
            Task { [weak self] in
                await self?.failRequest(requestID, error: CancellationError())
            }
        }
    }

    private func receiveLoop(task: URLSessionWebSocketTask, generation activeGeneration: Int) async {
        do {
            while !Task.isCancelled, activeGeneration == generation {
                let response = try await receiveObject(from: task)
                route(response)
            }
        } catch {
            failConnection(error, generation: activeGeneration)
        }
    }

    private func heartbeatLoop(task: URLSessionWebSocketTask, generation activeGeneration: Int) async {
        while !Task.isCancelled, activeGeneration == generation {
            do {
                try await Task.sleep(for: .seconds(timing.heartbeatIntervalSeconds))
                guard !Task.isCancelled, activeGeneration == generation else { return }
                try await sendPing(
                    through: task,
                    timeoutSeconds: timing.pingTimeoutSeconds
                )
            } catch is CancellationError {
                return
            } catch {
                failConnection(error, generation: activeGeneration)
                return
            }
        }
    }

    private func sendPing(
        through task: URLSessionWebSocketTask,
        timeoutSeconds: Double
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    task.sendPing { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                throw HomeAssistantClientError.timedOut
            }

            do {
                _ = try await group.next()
                group.cancelAll()
            } catch {
                if case HomeAssistantClientError.timedOut = error {
                    task.cancel(with: .goingAway, reason: nil)
                }
                group.cancelAll()
                throw error
            }
        }
    }

    private func failConnection(_ error: Error, generation activeGeneration: Int) {
        guard activeGeneration == generation else { return }
        generation += 1
        receiveTask?.cancel()
        receiveTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        finishConnection(with: error)
    }

    private func route(_ response: Response) {
        if let id = response["id"]?.numberValue.map({ Int($0) }),
           let pending = pendingRequests.removeValue(forKey: id) {
            pending.timeoutTask.cancel()
            if response["success"]?.boolValue == false {
                pending.continuation.resume(throwing: HomeAssistantClientError.server(errorMessage(from: response)))
            } else {
                pending.continuation.resume(returning: response)
            }
            return
        }

        guard
            response["type"]?.stringValue == "event",
            case let .object(event)? = response["event"],
            case let .object(data)? = event["data"],
            let entityID = data["entity_id"]?.stringValue
        else { return }

        let newState: HomeAssistantEntity?
        if case let .object(object)? = data["new_state"] {
            newState = HomeAssistantEntity(object: object)
        } else {
            newState = nil
        }
        stateContinuation?.yield(.init(entityID: entityID, newState: newState))
    }

    private func failRequest(_ id: Int, error: Error) {
        guard let pending = pendingRequests.removeValue(forKey: id) else { return }
        pending.timeoutTask.cancel()
        pending.continuation.resume(throwing: error)
    }

    private func finishConnection(with error: Error) {
        let requests = pendingRequests.values
        pendingRequests.removeAll()
        requests.forEach {
            $0.timeoutTask.cancel()
            $0.continuation.resume(throwing: error)
        }
        stateContinuation?.finish()
        stateContinuation = nil
        stateStream = nil
    }

    private func errorMessage(from response: Response) -> String {
        if let message = response["error"]?.stringValue { return message }
        if case let .object(error)? = response["error"],
           let message = error["message"]?.stringValue {
            return message
        }
        return "Der Home-Assistant-Aufruf ist fehlgeschlagen."
    }

    private func send(_ object: Response, through task: URLSessionWebSocketTask) async throws {
        let foundationObject = object.mapValues(\.foundationValue)
        let data = try JSONSerialization.data(withJSONObject: foundationObject)
        guard let text = String(data: data, encoding: .utf8) else {
            throw HomeAssistantClientError.invalidResponse
        }
        try await task.send(.string(text))
    }

    private func receiveObject(
        from task: URLSessionWebSocketTask,
        timeoutSeconds: Double? = nil
    ) async throws -> Response {
        guard let timeoutSeconds else {
            return try Self.decode(message: try await task.receive())
        }

        return try await withThrowingTaskGroup(of: Response.self) { group in
            group.addTask {
                try Self.decode(message: try await task.receive())
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                throw HomeAssistantClientError.timedOut
            }

            do {
                guard let response = try await group.next() else {
                    throw HomeAssistantClientError.disconnected
                }
                group.cancelAll()
                return response
            } catch {
                if case HomeAssistantClientError.timedOut = error {
                    task.cancel(with: .goingAway, reason: nil)
                }
                group.cancelAll()
                throw error
            }
        }
    }

    nonisolated private static func decode(
        message: URLSessionWebSocketTask.Message
    ) throws -> Response {
        let text: String
        switch message {
        case let .string(value): text = value
        case let .data(data): text = String(decoding: data, as: UTF8.self)
        @unknown default: throw HomeAssistantClientError.invalidResponse
        }
        guard let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            throw HomeAssistantClientError.invalidResponse
        }
        return object.compactMapValues(JSONValue.init(any:))
    }
}

private extension HomeAssistantEntity {
    init?(object: [String: JSONValue]) {
        guard let entityID = object["entity_id"]?.stringValue,
              let state = object["state"]?.stringValue else { return nil }
        let attributes: [String: JSONValue]
        if case let .object(value)? = object["attributes"] {
            attributes = value
        } else {
            attributes = [:]
        }
        self.init(entityID: entityID, state: state, attributes: attributes)
    }
}

extension JSONValue {
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
