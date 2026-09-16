import Foundation
import LocalAuthentication
import Observation

struct AdminIdentity: Codable, Equatable, Sendable {
    let subject: String
    let displayName: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case subject
        case displayName = "display_name"
        case role
    }
}

struct AdminBackendStatus: Codable, Equatable, Sendable {
    let version: String
    let environment: String
    let healthy: Bool
    let maintenanceMode: Bool
    let uptimeSeconds: Double
    let activeWebSocketSessions: Int
    let queueDepth: Int
    let cacheEntries: Int
    let databaseHealthy: Bool
    let lastBackup: Date?
    let chatQueuedChunks: Int?
    let chatQueuedBytes: Int?
    let chatDeviceQueues: Int?

    enum CodingKeys: String, CodingKey {
        case version
        case environment
        case healthy
        case maintenanceMode = "maintenance_mode"
        case uptimeSeconds = "uptime_seconds"
        case activeWebSocketSessions = "active_websocket_sessions"
        case queueDepth = "queue_depth"
        case cacheEntries = "cache_entries"
        case databaseHealthy = "database_healthy"
        case lastBackup = "last_backup"
        case chatQueuedChunks = "chat_queued_chunks"
        case chatQueuedBytes = "chat_queued_bytes"
        case chatDeviceQueues = "chat_device_queues"
    }
}

struct AdminAuditEvent: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let timestamp: Date
    let actor: String
    let action: String
    let result: String
}

struct AdminActionReceipt: Codable, Equatable, Sendable {
    let requestID: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case state
    }
}

enum AdminAction: String, CaseIterable, Identifiable, Sendable {
    case healthCheck = "health-check"
    case enableMaintenance = "maintenance-enable"
    case disableMaintenance = "maintenance-disable"
    case reconnectSessions = "reconnect-sessions"
    case clearCache = "clear-cache"
    case rotateLogs = "rotate-logs"
    case createBackup = "create-backup"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthCheck: "Vollständiger Health Check"
        case .enableMaintenance: "Wartungsmodus aktivieren"
        case .disableMaintenance: "Wartungsmodus beenden"
        case .reconnectSessions: "Verbindungen neu aufbauen"
        case .clearCache: "Cache sicher leeren"
        case .rotateLogs: "Logs rotieren"
        case .createBackup: "Backend-Backup erstellen"
        }
    }

    var symbol: String {
        switch self {
        case .healthCheck: "stethoscope"
        case .enableMaintenance, .disableMaintenance: "wrench.and.screwdriver.fill"
        case .reconnectSessions: "arrow.triangle.2.circlepath"
        case .clearCache: "trash.slash.fill"
        case .rotateLogs: "doc.text.fill"
        case .createBackup: "externaldrive.fill.badge.plus"
        }
    }

    var requiresFreshBiometrics: Bool { self != .healthCheck }
}

struct AdminControlConfiguration: Equatable, Sendable {
    let baseURL: URL
    let ownerToken: String
}

enum AdminControlError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case forbidden
    case rejected(Int)
    case biometricAuthenticationFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Admin-Backend-Adresse oder Owner-Token fehlt."
        case .invalidResponse: "Das Admin-Backend hat ungültige Daten gesendet."
        case .forbidden: "Dieses Konto besitzt keine Owner-Berechtigung."
        case let .rejected(code): "Das Admin-Backend hat die Anfrage abgelehnt (HTTP \(code))."
        case .biometricAuthenticationFailed: "Die Owner-Authentifizierung wurde nicht bestätigt."
        }
    }
}

actor AdminControlClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func identity(configuration: AdminControlConfiguration) async throws -> AdminIdentity {
        try await request(path: "v1/admin/session", method: "GET", configuration: configuration)
    }

    func status(configuration: AdminControlConfiguration) async throws -> AdminBackendStatus {
        try await request(path: "v1/admin/status", method: "GET", configuration: configuration)
    }

    func audit(configuration: AdminControlConfiguration) async throws -> [AdminAuditEvent] {
        try await request(path: "v1/admin/audit?limit=50", method: "GET", configuration: configuration)
    }

    func tickets(configuration: AdminControlConfiguration) async throws -> [SupportTicket] {
        try await request(path: "v1/admin/tickets?limit=100", method: "GET", configuration: configuration)
    }

    func projectRoutes(configuration: AdminControlConfiguration) async throws -> [ProjectRoute] {
        try await request(path: "v1/admin/projects", method: "GET", configuration: configuration)
    }

    func approveTicket(
        ticketID: String,
        projectID: String,
        configuration: AdminControlConfiguration
    ) async throws -> ProjectDispatch {
        try await request(
            path: "v1/admin/tickets/\(ticketID)/approve",
            method: "POST",
            body: SupportTicketApprovalRequest(projectID: projectID),
            configuration: configuration
        )
    }

    func ticket(id: String, configuration: AdminControlConfiguration) async throws -> SupportTicket {
        try await request(path: "v1/admin/tickets/\(id)", method: "GET", configuration: configuration)
    }

    func reply(
        ticketID: String,
        message: String,
        configuration: AdminControlConfiguration
    ) async throws -> SupportTicket {
        try await request(
            path: "v1/admin/tickets/\(ticketID)/messages",
            method: "POST",
            body: SupportTicketMessageRequest(message: message),
            configuration: configuration
        )
    }

    func updateTicketStatus(
        ticketID: String,
        status: String,
        configuration: AdminControlConfiguration
    ) async throws -> SupportTicket {
        try await request(
            path: "v1/admin/tickets/\(ticketID)/status",
            method: "POST",
            body: SupportTicketStatusRequest(status: status),
            configuration: configuration
        )
    }

    func perform(_ action: AdminAction, configuration: AdminControlConfiguration) async throws -> AdminActionReceipt {
        try await request(path: "v1/admin/actions/\(action.rawValue)", method: "POST", configuration: configuration)
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        configuration: AdminControlConfiguration
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: configuration.baseURL)?.absoluteURL else {
            throw AdminControlError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(configuration.ownerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AdminControlError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw AdminControlError.forbidden }
        guard (200..<300).contains(http.statusCode) else { throw AdminControlError.rejected(http.statusCode) }
        return try decoder.decode(Response.self, from: data)
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        configuration: AdminControlConfiguration
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: configuration.baseURL)?.absoluteURL else {
            throw AdminControlError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(configuration.ownerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AdminControlError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw AdminControlError.forbidden }
        guard (200..<300).contains(http.statusCode) else { throw AdminControlError.rejected(http.statusCode) }
        return try decoder.decode(Response.self, from: data)
    }
}

@MainActor
@Observable
final class AdminControlModel {
    enum State: Equatable {
        case notConfigured
        case locked
        case unlocking
        case unlocked(AdminIdentity)
        case failed(String)
    }

    var state: State = .notConfigured
    var backendStatus: AdminBackendStatus?
    var auditEvents: [AdminAuditEvent] = []
    var supportTickets: [SupportTicket] = []
    var ticketDetails: [String: SupportTicket] = [:]
    var projectRoutes: [ProjectRoute] = []
    var lastDispatch: ProjectDispatch?
    var isLoading = false
    var lastReceipt: AdminActionReceipt?
    var lastError: String?

    private let client = AdminControlClient()
    private let endpointKey = "ownerAdminEndpoint"
    private let tokenAccount = "ownerAdminToken"
    private var configuration: AdminControlConfiguration?

    init() {
        restoreConfiguration()
    }

    func configure(endpoint: String, ownerToken: String) throws {
        guard let url = URL(string: endpoint), url.scheme?.lowercased() == "https", !ownerToken.isEmpty else {
            throw AdminControlError.invalidConfiguration
        }
        configuration = .init(baseURL: url, ownerToken: ownerToken)
        UserDefaults.standard.set(url.absoluteString, forKey: endpointKey)
        try KeychainStore.save(ownerToken, account: tokenAccount)
        state = .locked
    }

    func unlock() async {
        guard let configuration else {
            state = .notConfigured
            return
        }
        state = .unlocking
        do {
            try await authenticateOwner(reason: "Geheimen Owner-Bereich öffnen")
            let identity = try await client.identity(configuration: configuration)
            guard identity.role == "owner" else { throw AdminControlError.forbidden }
            state = .unlocked(identity)
            await refresh()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func lock() {
        backendStatus = nil
        auditEvents = []
        supportTickets = []
        ticketDetails = [:]
        projectRoutes = []
        lastDispatch = nil
        state = configuration == nil ? .notConfigured : .locked
    }

    func refresh() async {
        guard case .unlocked = state, let configuration else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            lastError = nil
            async let status = client.status(configuration: configuration)
            async let audit = client.audit(configuration: configuration)
            async let tickets = client.tickets(configuration: configuration)
            async let routes = client.projectRoutes(configuration: configuration)
            backendStatus = try await status
            auditEvents = try await audit
            supportTickets = try await tickets
            projectRoutes = try await routes
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadTicket(_ id: String) async {
        guard case .unlocked = state, let configuration else { return }
        do {
            lastError = nil
            ticketDetails[id] = try await client.ticket(id: id, configuration: configuration)
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func replyToTicket(_ id: String, message: String) async -> Bool {
        guard case .unlocked = state, let configuration else { return false }
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 4000 else {
            lastError = "Die Antwort muss zwischen 1 und 4.000 Zeichen enthalten."
            return false
        }
        do {
            lastError = nil
            ticketDetails[id] = try await client.reply(
                ticketID: id,
                message: normalized,
                configuration: configuration
            )
            supportTickets = try await client.tickets(configuration: configuration)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func approveTicket(_ id: String, projectID: String) async -> Bool {
        guard case .unlocked = state, let configuration else { return false }
        guard projectRoutes.contains(where: { $0.id == projectID }) else {
            lastError = "Ungültiges Zielprojekt."
            return false
        }
        do {
            lastError = nil
            lastDispatch = try await client.approveTicket(
                ticketID: id,
                projectID: projectID,
                configuration: configuration
            )
            ticketDetails[id] = try await client.ticket(id: id, configuration: configuration)
            supportTickets = try await client.tickets(configuration: configuration)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func setTicketStatus(_ id: String, status: String) async {
        guard case .unlocked = state, let configuration else { return }
        do {
            lastError = nil
            ticketDetails[id] = try await client.updateTicketStatus(
                ticketID: id,
                status: status,
                configuration: configuration
            )
            supportTickets = try await client.tickets(configuration: configuration)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func perform(_ action: AdminAction) async {
        guard case .unlocked = state, let configuration else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            lastError = nil
            if action.requiresFreshBiometrics {
                try await authenticateOwner(reason: action.title)
            }
            lastReceipt = try await client.perform(action, configuration: configuration)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func removeConfiguration() {
        configuration = nil
        UserDefaults.standard.removeObject(forKey: endpointKey)
        KeychainStore.delete(account: tokenAccount)
        backendStatus = nil
        auditEvents = []
        supportTickets = []
        ticketDetails = [:]
        projectRoutes = []
        lastDispatch = nil
        lastError = nil
        state = .notConfigured
    }

    private func restoreConfiguration() {
        guard let endpoint = UserDefaults.standard.string(forKey: endpointKey),
              let url = URL(string: endpoint),
              let token = try? KeychainStore.value(account: tokenAccount),
              !token.isEmpty else { return }
        configuration = .init(baseURL: url, ownerToken: token)
        state = .locked
    }

    private func authenticateOwner(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Abbrechen"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AdminControlError.biometricAuthenticationFailed
        }
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
        guard success else { throw AdminControlError.biometricAuthenticationFailed }
    }
}
