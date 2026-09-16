import Foundation
import LocalAuthentication
import Observation

struct RunnerStatus: Codable, Equatable, Sendable {
    let vmOnline: Bool
    let serviceActive: Bool
    let registeredRunners: Int
    let idleRunners: Int
    let busyRunners: Int
    let cpuPercent: Double?
    let memoryPercent: Double?
    let diskPercent: Double?
    let lastHealthCheck: Date?

    enum CodingKeys: String, CodingKey {
        case vmOnline = "vm_online"
        case serviceActive = "service_active"
        case registeredRunners = "registered_runners"
        case idleRunners = "idle_runners"
        case busyRunners = "busy_runners"
        case cpuPercent = "cpu_percent"
        case memoryPercent = "memory_percent"
        case diskPercent = "disk_percent"
        case lastHealthCheck = "last_health_check"
    }
}

struct RunnerActionReceipt: Codable, Equatable, Sendable {
    let requestID: String
    let state: String
    let activeJobs: Int?

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case state
        case activeJobs = "active_jobs"
    }
}

enum RunnerAction: String, Codable, CaseIterable, Sendable {
    case healthCheck = "health-check"
    case pause
    case resume
    case gracefulRestart = "restart-gracefully"
    case shutdown

    var title: String {
        switch self {
        case .healthCheck: "Health Check"
        case .pause: "Pausieren"
        case .resume: "Fortsetzen"
        case .gracefulRestart: "Sicher neu starten"
        case .shutdown: "VM herunterfahren"
        }
    }

    var requiresBiometrics: Bool {
        self == .gracefulRestart || self == .shutdown
    }

    var path: String {
        switch self {
        case .healthCheck: "v1/health-check"
        case .pause: "v1/runners/pause"
        case .resume: "v1/runners/resume"
        case .gracefulRestart: "v1/runners/restart-gracefully"
        case .shutdown: "v1/vm/shutdown"
        }
    }
}

struct RunnerControlConfiguration: Equatable, Sendable {
    let baseURL: URL
    let token: String
}

enum RunnerControlError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case rejected(Int)
    case biometricAuthenticationFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Die Runner-Control-Adresse oder das Token fehlt."
        case .invalidResponse: "Der Runner-Control-Dienst hat ungültige Daten gesendet."
        case let .rejected(code): "Der Runner-Control-Dienst hat die Anfrage abgelehnt (HTTP \(code))."
        case .biometricAuthenticationFailed: "Die Aktion wurde nicht biometrisch bestätigt."
        }
    }
}

actor RunnerControlClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func status(configuration: RunnerControlConfiguration) async throws -> RunnerStatus {
        try await request(path: "v1/status", method: "GET", configuration: configuration)
    }

    func perform(_ action: RunnerAction, configuration: RunnerControlConfiguration) async throws -> RunnerActionReceipt {
        try await request(path: action.path, method: "POST", configuration: configuration)
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        configuration: RunnerControlConfiguration
    ) async throws -> Response {
        let url = configuration.baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RunnerControlError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw RunnerControlError.rejected(http.statusCode) }
        return try decoder.decode(Response.self, from: data)
    }
}

@MainActor
@Observable
final class RunnerControlModel {
    enum State: Equatable {
        case notConfigured
        case loading
        case ready(RunnerStatus)
        case failed(String)
    }

    var state: State = .notConfigured
    var isPresentingConfiguration = false
    var lastReceipt: RunnerActionReceipt?
    var lastError: String?

    private let client = RunnerControlClient()
    private let endpointKey = "runnerControlEndpoint"
    private let tokenAccount = "runnerControlToken"
    private var configuration: RunnerControlConfiguration?

    init() {
        restoreConfiguration()
    }

    func configure(endpoint: String, token: String) throws {
        guard let url = URL(string: endpoint), isAllowedScheme(url.scheme), !token.isEmpty else {
            throw RunnerControlError.invalidConfiguration
        }
        configuration = RunnerControlConfiguration(baseURL: url, token: token)
        UserDefaults.standard.set(url.absoluteString, forKey: endpointKey)
        try KeychainStore.save(token, account: tokenAccount)
        state = .loading
        isPresentingConfiguration = false
    }

    private func isAllowedScheme(_ scheme: String?) -> Bool {
        guard let scheme = scheme?.lowercased() else { return false }
#if DEBUG
        return ["http", "https"].contains(scheme)
#else
        return scheme == "https"
#endif
    }

    func refresh() async {
        guard let configuration else {
            state = .notConfigured
            return
        }
        if case .ready = state { } else { state = .loading }
        do {
            lastError = nil
            state = .ready(try await client.status(configuration: configuration))
        } catch {
            if case .ready = state {
                lastError = error.localizedDescription
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func perform(_ action: RunnerAction) async {
        guard let configuration else {
            state = .notConfigured
            return
        }
        do {
            lastError = nil
            if action.requiresBiometrics {
                try await authenticate()
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
        lastError = nil
        state = .notConfigured
    }

    private func restoreConfiguration() {
        guard let endpoint = UserDefaults.standard.string(forKey: endpointKey),
              let url = URL(string: endpoint),
              let token = try? KeychainStore.value(account: tokenAccount),
              !token.isEmpty else { return }
        configuration = RunnerControlConfiguration(baseURL: url, token: token)
        state = .loading
    }

    private func authenticate() async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw RunnerControlError.biometricAuthenticationFailed
        }
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Kritische Runner-Aktion bestätigen"
        )
        guard success else { throw RunnerControlError.biometricAuthenticationFailed }
    }
}
