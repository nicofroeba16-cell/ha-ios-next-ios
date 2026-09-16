import SwiftUI

struct ConnectionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let appModel: AppModel
    @State private var serverAddress = ""
#if DEBUG
    @State private var accessToken = ""
#endif

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://homeassistant.local:8123", text: $serverAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .submitLabel(.continue)

                    Button("Sicher mit Home Assistant anmelden", systemImage: "lock.shield.fill") {
                        guard let configuration = oauthConfiguration else { return }
                        Task { await appModel.connectOAuth(using: configuration) }
                    }
                    .disabled(oauthConfiguration == nil || appModel.connectionState == .connecting)
                } header: {
                    Text("Home-Assistant-Adresse")
                } footer: {
                    Text("Für die produktive Anmeldung ist eine HTTPS-Adresse erforderlich. Zugangsdaten werden nur im Schlüsselbund dieses Geräts gespeichert.")
                }

#if DEBUG
                Section("Lokale Entwicklungsverbindung") {
                    SecureField("Entwicklerzugriffstoken", text: $accessToken)
                        .textInputAutocapitalization(.never)
                        .textContentType(.password)
                        .autocorrectionDisabled()

                    Button("Direkt verbinden") {
                        guard let url = validatedDebugURL, !accessToken.isEmpty else { return }
                        Task { await appModel.connect(serverURL: url, accessToken: accessToken) }
                    }
                    .disabled(validatedDebugURL == nil || accessToken.isEmpty || appModel.connectionState == .connecting)
                }
#endif

                if appModel.connectionState == .connecting {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Verbindung wird hergestellt …")
                        }
                    }
                }

                if case let .failed(message) = appModel.connectionState {
                    Section {
                        IOSNextErrorBanner(message: message)
                    }
                }
            }
            .navigationTitle("Verbinden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private var oauthConfiguration: HomeAssistantOAuthConfiguration? {
        guard let instanceURL = normalizedURL, instanceURL.scheme == "https" else { return nil }
        return HomeAssistantOAuthConfiguration(
            instanceURL: instanceURL,
            clientID: HomeAssistantOAuthConfiguration.productionClientID
        )
    }

    private var normalizedURL: URL? {
        let value = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }

#if DEBUG
    private var validatedDebugURL: URL? {
        guard let url = normalizedURL, ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
        return url
    }
#endif
}
