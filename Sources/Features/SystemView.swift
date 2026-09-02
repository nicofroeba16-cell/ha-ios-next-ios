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
                Button("Entitäten aktualisieren") {
                    Task { await appModel.refresh() }
                }
                .disabled(appModel.connectionState == .connecting)
                Button("Verbindung entfernen", role: .destructive) {
                    appModel.forgetConnection()
                }
            }
            Section("System") {
                Label("\(appModel.entities.count) Entitäten geladen", systemImage: "circle.grid.2x2.fill")
                Label("Native iOS-App", systemImage: "iphone")
            }
        }
        .navigationTitle("System")
    }
}
