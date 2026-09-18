import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum ConnectionState: Equatable {
        case notConfigured
        case connecting
        case connected
        case reconnecting(Int)
        case failed(String)

        var statusText: String {
            switch self {
            case .notConfigured: "Nicht verbunden"
            case .connecting: "Verbinde …"
            case .connected: "Verbunden"
            case .reconnecting: "Verbindung wird wiederhergestellt …"
            case .failed: "Verbindung fehlgeschlagen"
            }
        }
    }

    var selectedProfile: HomeProfile = .timo
    var connectionState: ConnectionState = .notConfigured
    var entities: [HomeAssistantEntity] = []
    var areas: [HomeAssistantArea] = []
    var devices: [HomeAssistantDevice] = []
    var entityRegistry: [HomeAssistantRegistryEntity] = []
    var isPresentingConnection = false
    var lastActionError: String?

    private let client = HomeAssistantClient()
    private let oauthService = HomeAssistantOAuthService()
    private let serverURLKey = "homeAssistantServerURL"
    private let tokenAccount = "homeAssistantDeveloperToken"
    private let oauthCredentialAccount = "homeAssistantOAuthCredential"
    private var activeConfiguration: HomeAssistantConfiguration?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectGeneration = 0

    var isConnected: Bool {
        switch connectionState {
        case .connected, .reconnecting: true
        default: false
        }
    }

    var profileDefinition: ProfileDefinition {
        ProfileCatalog.definition(for: selectedProfile)
    }

    var profileFavorites: [HomeAssistantEntity] {
        let explicit = profileDefinition.favoriteEntityIDs.compactMap { requestedID in
            entities.first { $0.entityID == requestedID }
        }
        guard explicit.isEmpty else { return explicit }
        let areaIDs = Set(areas.filter { area in
            profileDefinition.roomNames.contains { room in
                area.name.localizedCaseInsensitiveCompare(room) == .orderedSame
            }
        }.map(\.id))
        return areaIDs
            .flatMap(entities(inArea:))
            .filter { $0.controlKind != .readOnly }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            .prefix(6)
            .map { $0 }
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
            await connect(serverURL: configuration.instanceURL, accessToken: credential.accessToken, persist: false)
            guard connectionState == .connected else { return }
            try saveOAuthCredential(credential)
            KeychainStore.delete(account: tokenAccount)
            UserDefaults.standard.removeObject(forKey: serverURLKey)
        } catch {
            connectionState = .failed(error.localizedDescription)
        }
    }

    func connect(serverURL: URL, accessToken: String, persist: Bool = true) async {
        reconnectGeneration += 1
        reconnectTask?.cancel()
        reconnectTask = nil
        connectionState = .connecting
        do {
            let configuration = HomeAssistantConfiguration(baseURL: serverURL, accessToken: accessToken)
            await installClientHandlers()
            let snapshot = try await client.connect(configuration: configuration)
            activeConfiguration = configuration
            reconnectTask?.cancel()
            entities = snapshot.states.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            areas = snapshot.areas
            devices = snapshot.devices
            entityRegistry = snapshot.entityRegistry
            connectionState = .connected
            lastActionError = nil
            isPresentingConnection = false
            if persist {
                UserDefaults.standard.set(serverURL.absoluteString, forKey: serverURLKey)
                try KeychainStore.save(accessToken, account: tokenAccount)
            }
        } catch {
            connectionState = .failed(error.localizedDescription)
        }
    }

    func disconnect() {
        reconnectGeneration += 1
        reconnectTask?.cancel()
        reconnectTask = nil
        activeConfiguration = nil
        Task { await client.disconnect() }
        entities = []
        areas = []
        devices = []
        entityRegistry = []
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
        let parts = entity.entityID.split(separator: ".", maxSplits: 1).map(String.init)
        guard let domain = parts.first else { return }
        let service = entity.isOn ? "turn_off" : "turn_on"
        do {
            try await client.callService(domain: domain, service: service, targetEntityID: entity.entityID)
            if let index = entities.firstIndex(where: { $0.id == entity.id }) {
                entities[index] = entity.updating(state: service == "turn_on" ? "on" : "off")
            }
        } catch {
            lastActionError = error.localizedDescription
        }
    }

    func activate(_ scene: HomeAssistantEntity) async {
        do {
            try await client.callService(domain: "scene", service: "turn_on", targetEntityID: scene.entityID)
        } catch {
            lastActionError = error.localizedDescription
        }
    }

    func callService(
        for entity: HomeAssistantEntity,
        service: String,
        data: [String: Any] = [:]
    ) async {
        do {
            try await client.callService(
                domain: entity.domain,
                service: service,
                targetEntityID: entity.entityID,
                serviceData: data
            )
            lastActionError = nil
        } catch {
            lastActionError = error.localizedDescription
        }
    }

    func setBrightness(_ value: Double, for light: HomeAssistantEntity) async {
        let normalized = min(max(value, 0), 1)
        await callService(
            for: light,
            service: "turn_on",
            data: ["brightness": Int((normalized * 255).rounded())]
        )
    }

    func setVolume(_ value: Double, for player: HomeAssistantEntity) async {
        await callService(
            for: player,
            service: "volume_set",
            data: ["volume_level": min(max(value, 0), 1)]
        )
    }

    func setTemperature(_ value: Double, for climate: HomeAssistantEntity) async {
        await callService(for: climate, service: "set_temperature", data: ["temperature": value])
    }

    func setCoverPosition(_ value: Double, for cover: HomeAssistantEntity) async {
        let normalized = min(max(value, 0), 100)
        await callService(
            for: cover,
            service: "set_cover_position",
            data: ["position": Int(normalized.rounded())]
        )
    }

    func setLocked(_ locked: Bool, for entity: HomeAssistantEntity) async {
        await callService(for: entity, service: locked ? "lock" : "unlock")
    }

    func activateScript(_ script: HomeAssistantEntity) async {
        await callService(for: script, service: "turn_on")
    }

    func entities(inDomain domain: String) -> [HomeAssistantEntity] {
        entities.filter { $0.domain == domain }
    }

    func entities(inArea areaID: String) -> [HomeAssistantEntity] {
        let ids = Set(entityRegistry.filter { $0.areaID == areaID }.map(\.entityID))
        let deviceIDs = Set(devices.filter { $0.areaID == areaID }.map(\.id))
        let deviceEntityIDs = Set(entityRegistry.filter { registry in
            registry.deviceID.map(deviceIDs.contains) ?? false
        }.map(\.entityID))
        return entities.filter { ids.contains($0.entityID) || deviceEntityIDs.contains($0.entityID) }
    }

    private func installClientHandlers() async {
        await client.setEventHandler { [weak self] change in
            await self?.applyLiveChange(change)
        }
        await client.setDisconnectHandler { [weak self] error in
            await self?.connectionDropped(error)
        }
    }

    private func applyLiveChange(_ change: HomeAssistantStateChange) {
        switch change {
        case let .updated(entity):
            if let index = entities.firstIndex(where: { $0.entityID == entity.entityID }) {
                entities[index] = entity
            } else {
                entities.append(entity)
                entities.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            }
        case let .removed(entityID):
            entities.removeAll { $0.entityID == entityID }
        }
    }

    private func connectionDropped(_ error: Error) {
        guard activeConfiguration != nil, reconnectTask == nil else { return }
        reconnectGeneration += 1
        let generation = reconnectGeneration
        reconnectTask = Task { [weak self] in
            await self?.reconnect(generation: generation, initialError: error)
        }
    }

    private func reconnect(generation: Int, initialError: Error) async {
        var lastError = initialError
        for attempt in 1 ... 5 {
            guard generation == reconnectGeneration, let configuration = activeConfiguration else { return }
            connectionState = .reconnecting(attempt)
            let delay = min(pow(2.0, Double(attempt - 1)), 16)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, generation == reconnectGeneration else { return }
            do {
                let snapshot = try await client.connect(configuration: configuration)
                apply(snapshot)
                connectionState = .connected
                reconnectTask = nil
                return
            } catch {
                lastError = error
            }
        }
        reconnectTask = nil
        connectionState = .failed(lastError.localizedDescription)
    }

    private func apply(_ snapshot: HomeAssistantSnapshot) {
        entities = snapshot.states.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        areas = snapshot.areas
        devices = snapshot.devices
        entityRegistry = snapshot.entityRegistry
    }

    private func oauthCredential() throws -> HomeAssistantOAuthCredential? {
        guard let data = try KeychainStore.data(account: oauthCredentialAccount) else { return nil }
        return try JSONDecoder().decode(HomeAssistantOAuthCredential.self, from: data)
    }

    private func saveOAuthCredential(_ credential: HomeAssistantOAuthCredential) throws {
        try KeychainStore.save(JSONEncoder().encode(credential), account: oauthCredentialAccount)
    }
}
