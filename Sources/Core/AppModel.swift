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

    private let client = HomeAssistantClient()
    private let oauthService = HomeAssistantOAuthService()
    private let serverURLKey = "homeAssistantServerURL"
    private let tokenAccount = "homeAssistantDeveloperToken"
    private let oauthCredentialAccount = "homeAssistantOAuthCredential"

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    var profileDefinition: ProfileDefinition {
        ProfileCatalog.definition(for: selectedProfile)
    }

    var profileFavorites: [HomeAssistantEntity] {
        profileDefinition.favoriteEntityIDs.compactMap { requestedID in
            entities.first { $0.entityID == requestedID }
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
        connectionState = .connecting
        do {
            let states = try await client.connect(configuration: .init(baseURL: serverURL, accessToken: accessToken))
            entities = states.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            connectionState = .connected
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
        Task { await client.disconnect() }
        entities = []
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
            connectionState = .failed(error.localizedDescription)
        }
    }

    func activate(_ scene: HomeAssistantEntity) async {
        do {
            try await client.callService(domain: "scene", service: "turn_on", targetEntityID: scene.entityID)
        } catch {
            connectionState = .failed(error.localizedDescription)
        }
    }

    func entities(inDomain domain: String) -> [HomeAssistantEntity] {
        entities.filter { $0.entityID.hasPrefix("\(domain).") }
    }

    private func oauthCredential() throws -> HomeAssistantOAuthCredential? {
        guard let data = try KeychainStore.data(account: oauthCredentialAccount) else { return nil }
        return try JSONDecoder().decode(HomeAssistantOAuthCredential.self, from: data)
    }

    private func saveOAuthCredential(_ credential: HomeAssistantOAuthCredential) throws {
        try KeychainStore.save(JSONEncoder().encode(credential), account: oauthCredentialAccount)
    }
}
