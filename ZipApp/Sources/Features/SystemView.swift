import SwiftUI

struct SystemView: View {
    let appModel: AppModel

    var body: some View {
        List {
            Section("Verbindung") {
                HStack {
                    Label("Home Assistant", systemImage: "house.fill")
                    Spacer()
                    ConnectionStatusLabel(state: appModel.connectionState)
                }
                Button("Verbindung verwalten") {
                    appModel.isPresentingConnection = true
                }
                Button("Daten aktualisieren") {
                    Task { await appModel.refresh() }
                }
                .disabled(isBusy)
                Button("Verbindung entfernen", role: .destructive) {
                    appModel.forgetConnection()
                }
            }
            if let error = appModel.lastActionError {
                Section("Letzter Aktionsfehler") {
                    Text(error).foregroundStyle(.red)
                }
            }
            Section("Home Assistant") {
                LabeledContent("Entitäten", value: "\(appModel.entities.count)")
                LabeledContent("Areas", value: "\(appModel.areas.count)")
                LabeledContent("Geräte", value: "\(appModel.devices.count)")
                LabeledContent("Registry", value: "\(appModel.entityRegistry.count)")
            }
            Section("App") {
                Label("Native iOS-App", systemImage: "iphone")
                Label("Live-State-Synchronisierung", systemImage: "bolt.horizontal.circle")
                Label("Automatischer Reconnect", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .navigationTitle("System")
    }

    private var isBusy: Bool {
        switch appModel.connectionState {
        case .connecting, .reconnecting: true
        default: false
        }
    }
}
