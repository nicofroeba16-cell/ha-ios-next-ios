import SwiftUI

struct ConnectionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let appModel: AppModel
    @State private var serverAddress = ""
    @State private var accessToken = ""
    @State private var oauthClientID = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Produktionsanmeldung") {
                    TextField("https://homeassistant.local:8123", text: $serverAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("HTTPS-URL der iOS-Next-Client-ID", text: $oauthClientID)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button("Mit Home Assistant anmelden") {
                        guard let configuration = oauthConfiguration else { return }
                        Task { await appModel.connectOAuth(using: configuration) }
                    }
                    .disabled(oauthConfiguration == nil || appModel.connectionState == .connecting)
                }
                Section("Lokale Entwicklungsverbindung") {
                    SecureField("Entwicklerzugriffstoken", text: $accessToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Die Produktionsanmeldung benötigt eine veröffentlichte HTTPS-Client-ID-Seite, die den iOS-Next-Redirect bestätigt. Der Entwickler-Token wird ausschließlich im iOS-Schlüsselbund gespeichert und ist nicht für öffentliche Builds bestimmt.")
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verbinden") {
                        guard let url = URL(string: serverAddress), !accessToken.isEmpty else { return }
                        Task { await appModel.connect(serverURL: url, accessToken: accessToken) }
                    }
                    .disabled(URL(string: serverAddress) == nil || accessToken.isEmpty || appModel.connectionState == .connecting)
                }
            }
        }
    }

    private var oauthConfiguration: HomeAssistantOAuthConfiguration? {
        guard
            let instanceURL = URL(string: serverAddress),
            let clientID = URL(string: oauthClientID),
            clientID.scheme == "https"
        else { return nil }
        return HomeAssistantOAuthConfiguration(instanceURL: instanceURL, clientID: clientID)
    }
}
