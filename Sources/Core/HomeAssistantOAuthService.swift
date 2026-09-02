import AuthenticationServices
import Foundation

struct HomeAssistantOAuthConfiguration: Equatable, Sendable {
    let instanceURL: URL
    let clientID: URL

    static let redirectURL = URL(string: "iosnext://auth")!

    var authorizationURL: URL? {
        var components = URLComponents(url: instanceURL.appending(path: "auth/authorize"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID.absoluteString),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURL.absoluteString)
        ]
        return components?.url
    }

    var tokenURL: URL {
        instanceURL.appending(path: "auth/token")
    }
}

struct HomeAssistantOAuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct HomeAssistantOAuthCredential: Codable, Equatable, Sendable {
    let configuration: HomeAssistantOAuthConfiguration
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    var needsRefresh: Bool {
        expiresAt <= Date().addingTimeInterval(60)
    }
}

extension HomeAssistantOAuthConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case instanceURL
        case clientID
    }
}

enum HomeAssistantOAuthError: LocalizedError {
    case invalidConfiguration
    case missingAuthorizationCode
    case callbackMismatch
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Die OAuth-Konfiguration ist ungültig."
        case .missingAuthorizationCode: "Home Assistant hat keinen Autorisierungscode zurückgegeben."
        case .callbackMismatch: "Der OAuth-Rückruf gehört nicht zu iOS Next."
        case .tokenExchangeFailed: "Die Home-Assistant-Tokens konnten nicht abgerufen werden."
        }
    }
}

@MainActor
final class HomeAssistantOAuthService {
    private var authenticationSession: ASWebAuthenticationSession?

    func authorize(using configuration: HomeAssistantOAuthConfiguration) async throws -> HomeAssistantOAuthTokens {
        guard let authorizationURL = configuration.authorizationURL else {
            throw HomeAssistantOAuthError.invalidConfiguration
        }
        let callbackURL = try await openAuthorizationSession(url: authorizationURL)
        guard callbackURL.scheme == HomeAssistantOAuthConfiguration.redirectURL.scheme else {
            throw HomeAssistantOAuthError.callbackMismatch
        }
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value,
            !code.isEmpty
        else {
            throw HomeAssistantOAuthError.missingAuthorizationCode
        }
        return try await exchange(code: code, using: configuration)
    }

    func refresh(_ credential: HomeAssistantOAuthCredential) async throws -> HomeAssistantOAuthCredential {
        guard credential.needsRefresh else { return credential }
        var request = URLRequest(url: credential.configuration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "grant_type": "refresh_token",
            "refresh_token": credential.refreshToken,
            "client_id": credential.configuration.clientID.absoluteString
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
            throw HomeAssistantOAuthError.tokenExchangeFailed
        }
        let tokens = try JSONDecoder().decode(HomeAssistantOAuthRefreshTokens.self, from: data)
        return HomeAssistantOAuthCredential(
            configuration: credential.configuration,
            accessToken: tokens.accessToken,
            refreshToken: credential.refreshToken,
            expiresAt: Date().addingTimeInterval(tokens.expiresIn)
        )
    }

    private func openAuthorizationSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: HomeAssistantOAuthConfiguration.redirectURL.scheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: HomeAssistantOAuthError.callbackMismatch)
                }
            }
            session.prefersEphemeralWebBrowserSession = false
            authenticationSession = session
            session.start()
        }
    }

    private func exchange(code: String, using configuration: HomeAssistantOAuthConfiguration) async throws -> HomeAssistantOAuthTokens {
        var request = URLRequest(url: configuration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "grant_type": "authorization_code",
            "code": code,
            "client_id": configuration.clientID.absoluteString
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
            throw HomeAssistantOAuthError.tokenExchangeFailed
        }
        return try JSONDecoder().decode(HomeAssistantOAuthTokens.self, from: data)
    }

    private func formBody(_ parameters: [String: String]) -> Data? {
        let value = parameters
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(key.percentEncodedForForm)=\(value.percentEncodedForForm)"
            }
            .joined(separator: "&")
        return Data(value.utf8)
    }
}

private struct HomeAssistantOAuthRefreshTokens: Codable {
    let accessToken: String
    let expiresIn: TimeInterval

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private extension String {
    var percentEncodedForForm: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))) ?? self
    }
}
