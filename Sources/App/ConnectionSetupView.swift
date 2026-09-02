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
                Section("Produktionsanmeldung") {
                    TextField("https://homeassistant.local:8123", text: $serverAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button("Mit Home Assistant anmelden") {
                        guard let configuration = oauthConfiguration else { return }
                        Task { await appModel.connectOAuth(using: configuration) }
                    }
                    .disabled(oauthConfiguration == nil || appModel.connectionState == .connecting)
                }
#if DEBUG
                Section("Lokale Entwicklungsverbindung") {
                    SecureField("Entwicklerzugriffstoken", text: $accessToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
#endif
                Section {
                    Text("Die Anmeldung nutzt die veröffentlichte iOS-Next-Client-ID. Zugangsdaten bleiben ausschließlich im iOS-Schlüsselbund.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if case let .failed(message) = appModel.connectionState {
                    Section { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Verbinden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
#if DEBUG
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verbinden") {
                        guard let url = URL(string: serverAddress), !accessToken.isEmpty else { return }
                        Task { await appModel.connect(serverURL: url, accessToken: accessToken) }
                    }
                    .disabled(URL(string: serverAddress) == nil || accessToken.isEmpty || appModel.connectionState == .connecting)
                }
#endif
            }
        }
    }

    private var oauthConfiguration: HomeAssistantOAuthConfiguration? {
        guard
            let instanceURL = URL(string: serverAddress),
            instanceURL.scheme == "https"
        else { return nil }
        return HomeAssistantOAuthConfiguration(
            instanceURL: instanceURL,
            clientID: HomeAssistantOAuthConfiguration.productionClientID
        )
    }
}
