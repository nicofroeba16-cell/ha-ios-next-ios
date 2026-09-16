import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum ConnectionState: Equatable {
        case notConfigured
        case connecting
        case connected
        case failed(String)

        var statusText: String {
            switch self {
            case .notConfigured: "Nicht verbunden"
            case .connecting: "Verbinde …"
            case .connected: "Verbunden"
            case .failed: "Verbindung fehlgeschlagen"
            }
        }
    }

    var selectedProfile: HomeProfile = .timo
    var connectionState: ConnectionState = .notConfigured
    var entities: [HomeAssistantEntity] = []
    var isPresentingConnection = false
    var activeActionEntityIDs: Set<String> = []
    var lastActionError: String?

    private let client = HomeAssistantClient()
    private let oauthService = HomeAssistantOAuthService()
    private let serverURLKey = "homeAssistantServerURL"
    private let tokenAccount = "homeAssistantDeveloperToken"
    private let oauthCredentialAccount = "homeAssistantOAuthCredential"
    private var eventTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var currentConfiguration: HomeAssistantConfiguration?
    private var shouldReconnect = false
    private var reconnectAttempt = 0
    private var entityIndexByID: [String: Int] = [:]
    private var pendingStateChanges: [String: HomeAssistantStateChange] = [:]
    private var stateFlushTask: Task<Void, Never>?
    private let reachability = NetworkReachability()
    private var networkTask: Task<Void, Never>?
    private var networkAvailable = true
    private var applicationIsActive = true

    init() {
        let reachability = self.reachability
        networkTask = Task { [weak self, reachability] in
            for await available in reachability.statuses() {
                guard !Task.isCancelled else { return }
                self?.handleNetworkAvailability(available)
            }
        }
    }

    deinit {
        networkTask?.cancel()
    }

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    var profileDefinition: ProfileDefinition {
        ProfileCatalog.definition(for: selectedProfile)
    }

    var profileFavorites: [HomeAssistantEntity] {
        profileDefinition.favoriteEntityIDs.compactMap { requestedID in
            if let index = entityIndexByID[requestedID], entities.indices.contains(index) {
                return entities[index]
            }
            return entities.first { $0.entityID == requestedID }
        }
    }

    func restoreConnection() async {
        if let credential = try? oauthCredential() {
            do {
                let refreshed = try await oauthService.refresh(credential)
                try saveOAuthCredential(refreshed)
                await connect(serverURL: refreshed.configuration.instanceURL, accessToken: refreshed.accessToken, persist: false)
                return
            } catch {
                connectionState = .failed(error.localizedDescription)
                return
            }
        }
        guard
            let address = UserDefaults.standard.string(forKey: serverURLKey),
            let url = URL(string: address),
            let token = try? KeychainStore.value(account: tokenAccount),
            !token.isEmpty
        else { return }
        await connect(serverURL: url, accessToken: token, persist: false)
    }

    func connectOAuth(using configuration: HomeAssistantOAuthConfiguration) async {
        connectionState = .connecting
        do {
            let tokens = try await oauthService.authorize(using: configuration)
            let credential = HomeAssistantOAuthCredential(
                configuration: configuration,
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresAt: Date().addingTimeInterval(tokens.expiresIn)
            )
            try saveOAuthCredential(credential)
            KeychainStore.delete(account: tokenAccount)
            UserDefaults.standard.removeObject(forKey: serverURLKey)
            await connect(serverURL: configuration.instanceURL, accessToken: credential.accessToken, persist: false)
        } catch {
            connectionState = .failed(error.localizedDescription)
        }
    }

    func connect(serverURL: URL, accessToken: String, persist: Bool = true) async {
        reconnectTask?.cancel()
        reconnectTask = nil
        eventTask?.cancel()
        eventTask = nil
        stateFlushTask?.cancel()
        stateFlushTask = nil
        pendingStateChanges.removeAll()
        connectionState = .connecting
        let configuration = HomeAssistantConfiguration(baseURL: serverURL, accessToken: accessToken)
        do {
            let states = try await client.connect(configuration: configuration)
            currentConfiguration = configuration
            shouldReconnect = true
            reconnectAttempt = 0
            replaceEntities(with: states)
            connectionState = .connected
            isPresentingConnection = false
            observeStateChanges()
            if persist {
                UserDefaults.standard.set(serverURL.absoluteString, forKey: serverURLKey)
                try KeychainStore.save(accessToken, account: tokenAccount)
            }
        } catch {
            connectionState = .failed(error.localizedDescription)
        }
    }

    func disconnect() {
        shouldReconnect = false
        currentConfiguration = nil
        eventTask?.cancel()
        eventTask = nil
        stateFlushTask?.cancel()
        stateFlushTask = nil
        pendingStateChanges.removeAll()
        reconnectTask?.cancel()
        reconnectTask = nil
        Task { await client.disconnect() }
        entities = []
        entityIndexByID.removeAll()
        connectionState = .notConfigured
    }

    func refresh() async {
        if let credential = try? oauthCredential() {
            do {
                let refreshed = try await oauthService.refresh(credential)
                try saveOAuthCredential(refreshed)
                await connect(serverURL: refreshed.configuration.instanceURL, accessToken: refreshed.accessToken, persist: false)
                return
            } catch {
                connectionState = .failed(error.localizedDescription)
                return
            }
        }
        guard
            let address = UserDefaults.standard.string(forKey: serverURLKey),
            let url = URL(string: address),
            let token = try? KeychainStore.value(account: tokenAccount),
            !token.isEmpty
        else {
            connectionState = .notConfigured
            return
        }
        await connect(serverURL: url, accessToken: token, persist: false)
    }

    func forgetConnection() {
        disconnect()
        UserDefaults.standard.removeObject(forKey: serverURLKey)
        KeychainStore.delete(account: tokenAccount)
        KeychainStore.delete(account: oauthCredentialAccount)
    }

    func toggle(_ entity: HomeAssistantEntity) async {
        let service: String
        let optimisticState: String
        if entity.domain == "lock" {
            service = entity.state == "locked" ? "unlock" : "lock"
            optimisticState = service == "lock" ? "locked" : "unlocked"
        } else {
            service = entity.isOn ? "turn_off" : "turn_on"
            optimisticState = service == "turn_on" ? "on" : "off"
        }
        await performService(
            domain: entity.domain,
            service: service,
            entity: entity,
            optimisticState: optimisticState
        )
    }

    func activate(_ scene: HomeAssistantEntity) async {
        await performService(domain: "scene", service: "turn_on", entity: scene)
    }

    func setBrightness(_ value: Double, for light: HomeAssistantEntity) async {
        await performService(
            domain: "light",
            service: "turn_on",
            entity: light,
            data: ["brightness_pct": .number((min(max(value, 0), 1) * 100).rounded())],
            optimisticState: "on"
        )
    }

    func mediaCommand(_ service: String, for player: HomeAssistantEntity) async {
        await performService(domain: "media_player", service: service, entity: player)
    }

    func setVolume(_ value: Double, for player: HomeAssistantEntity) async {
        await performService(
            domain: "media_player",
            service: "volume_set",
            entity: player,
            data: ["volume_level": .number(min(max(value, 0), 1))]
        )
    }

    func seek(to seconds: Double, for player: HomeAssistantEntity) async {
        await performService(
            domain: "media_player",
            service: "media_seek",
            entity: player,
            data: ["seek_position": .number(max(seconds, 0))]
        )
    }

    func coverCommand(_ service: String, for cover: HomeAssistantEntity) async {
        await performService(domain: "cover", service: service, entity: cover)
    }

    func setCoverPosition(_ value: Double, for cover: HomeAssistantEntity) async {
        await performService(
            domain: "cover",
            service: "set_cover_position",
            entity: cover,
            data: ["position": .number((min(max(value, 0), 1) * 100).rounded())]
        )
    }

    func setTemperature(_ value: Double, for climate: HomeAssistantEntity) async {
        await performService(
            domain: "climate",
            service: "set_temperature",
            entity: climate,
            data: ["temperature": .number(value)]
        )
    }

    func dismissActionError() {
        lastActionError = nil
    }

    func setApplicationActive(_ active: Bool) {
        applicationIsActive = active
        if active {
            if shouldReconnect, currentConfiguration != nil, !isConnected {
                scheduleReconnect(immediate: true)
            }
        } else {
            reconnectTask?.cancel()
            reconnectTask = nil
        }
    }

    func entities(inDomain domain: String) -> [HomeAssistantEntity] {
        entities.filter { $0.entityID.hasPrefix("\(domain).") }
    }

    private func observeStateChanges() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            guard let self else { return }
            let stream = await client.stateChanges()
            for await change in stream {
                guard !Task.isCancelled else { return }
                enqueue(change)
            }
            guard !Task.isCancelled else { return }
            connectionState = .connecting
            scheduleReconnect()
        }
    }

    private func enqueue(_ change: HomeAssistantStateChange) {
        pendingStateChanges[change.entityID] = change
        guard stateFlushTask == nil else { return }
        stateFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled, let self else { return }
            flushStateChanges()
        }
    }

    private func flushStateChanges() {
        let changes = Array(pendingStateChanges.values)
        pendingStateChanges.removeAll(keepingCapacity: true)
        stateFlushTask = nil
        var requiresReindex = false
        var removedEntityIDs: Set<String> = []

        for change in changes {
            if let newState = change.newState {
                if let index = entityIndexByID[change.entityID], entities.indices.contains(index) {
                    entities[index] = newState
                } else {
                    entities.append(newState)
                    requiresReindex = true
                }
            } else {
                removedEntityIDs.insert(change.entityID)
            }
        }

        if !removedEntityIDs.isEmpty {
            entities.removeAll { removedEntityIDs.contains($0.entityID) }
            requiresReindex = true
        }

        if requiresReindex {
            sortEntities()
        }
    }

    static func reconnectDelaySeconds(attempt: Int, jitterFraction: Double) -> Double {
        let base = min(pow(2.0, Double(max(attempt, 1) - 1)), 30)
        let boundedJitter = min(max(jitterFraction, -0.2), 0.2)
        return max(0.25, base * (1 + boundedJitter))
    }

    private func scheduleReconnect(immediate: Bool = false) {
        guard shouldReconnect,
              currentConfiguration != nil,
              applicationIsActive,
              networkAvailable else { return }

        connectionState = .connecting
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            reconnectAttempt += 1
            if !immediate {
                let jitter = Double.random(in: -0.2...0.2)
                let seconds = Self.reconnectDelaySeconds(
                    attempt: reconnectAttempt,
                    jitterFraction: jitter
                )
                try? await Task.sleep(for: .seconds(seconds))
            }
            guard !Task.isCancelled,
                  shouldReconnect,
                  applicationIsActive,
                  networkAvailable,
                  let configuration = currentConfiguration else { return }
            do {
                let states = try await client.connect(configuration: configuration)
                replaceEntities(with: states)
                reconnectAttempt = 0
                connectionState = .connected
                observeStateChanges()
            } catch {
                guard !Task.isCancelled else { return }
                lastActionError = "Erneute Verbindung fehlgeschlagen: \(error.localizedDescription)"
                scheduleReconnect()
            }
        }
    }

    private func handleNetworkAvailability(_ available: Bool) {
        guard networkAvailable != available else { return }
        networkAvailable = available

        if available {
            if shouldReconnect, currentConfiguration != nil, !isConnected, applicationIsActive {
                scheduleReconnect(immediate: true)
            }
        } else {
            reconnectTask?.cancel()
            reconnectTask = nil
            guard shouldReconnect, currentConfiguration != nil else { return }
            connectionState = .connecting
            Task { await client.disconnect() }
        }
    }

    private func replaceEntities(with states: [HomeAssistantEntity]) {
        entities = states
        sortEntities()
    }

    private func sortEntities() {
        entities.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        entityIndexByID = Dictionary(uniqueKeysWithValues: entities.enumerated().map { ($0.element.entityID, $0.offset) })
    }

    private func performService(
        domain: String,
        service: String,
        entity: HomeAssistantEntity,
        data: [String: JSONValue] = [:],
        optimisticState: String? = nil
    ) async {
        guard entity.isAvailable, !activeActionEntityIDs.contains(entity.entityID) else { return }
        activeActionEntityIDs.insert(entity.entityID)
        lastActionError = nil
        defer { activeActionEntityIDs.remove(entity.entityID) }

        do {
            try await client.callService(
                domain: domain,
                service: service,
                targetEntityID: entity.entityID,
                serviceData: data
            )
            if let optimisticState,
               let index = entities.firstIndex(where: { $0.id == entity.id }) {
                entities[index] = entity.updating(state: optimisticState)
            }
        } catch {
            lastActionError = error.localizedDescription
        }
    }

    private func oauthCredential() throws -> HomeAssistantOAuthCredential? {
        guard let data = try KeychainStore.data(account: oauthCredentialAccount) else { return nil }
        return try JSONDecoder().decode(HomeAssistantOAuthCredential.self, from: data)
    }

    private func saveOAuthCredential(_ credential: HomeAssistantOAuthCredential) throws {
        try KeychainStore.save(JSONEncoder().encode(credential), account: oauthCredentialAccount)
    }
}
