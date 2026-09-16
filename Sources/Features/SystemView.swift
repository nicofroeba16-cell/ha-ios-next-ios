import SwiftUI

struct SystemView: View {
    let appModel: AppModel
    @State private var ownerTapCount = 0
    @State private var isPresentingOwnerArea = false

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Home Assistant", systemImage: "house.fill")
                    Spacer()
                    ConnectionStatusLabel(state: appModel.connectionState)
                }
                Button("Entitäten aktualisieren", systemImage: "arrow.clockwise") {
                    Task { await appModel.refresh() }
                }
                .disabled(appModel.connectionState == .connecting)
                Button("Verbindung verwalten", systemImage: "link") {
                    appModel.isPresentingConnection = true
                }
            } header: {
                Text("Verbindung")
            } footer: {
                Text("Statusänderungen werden nach der Anmeldung live über die Home-Assistant-WebSocket-Verbindung empfangen.")
            }

            Section("Verwaltung") {
                NavigationLink {
                    WireGuardView()
                } label: {
                    Label("Fernzugriff · WireGuard", systemImage: "network.badge.shield.half.filled")
                }
                NavigationLink {
                    ScenesView(appModel: appModel)
                } label: {
                    Label("Szenen", systemImage: "sparkles")
                }
                NavigationLink {
                    RunnerDashboardView()
                } label: {
                    Label("Runner", systemImage: "server.rack")
                }
                NavigationLink {
                    DiagnosticsView(appModel: appModel)
                } label: {
                    Label("Diagnose", systemImage: "stethoscope")
                }
            }

            Section("App") {
                LabeledContent("Entitäten", value: "\(appModel.entities.count)")
                LabeledContent("Oberfläche", value: "iOS 27")
                    .contentShape(Rectangle())
                    .onTapGesture {
                        ownerTapCount += 1
                        if ownerTapCount >= 7 {
                            ownerTapCount = 0
                            isPresentingOwnerArea = true
                        }
                    }
                LabeledContent("Technik", value: "SwiftUI")
            }

            Section {
                Button("Verbindung und Zugangsdaten entfernen", role: .destructive) {
                    appModel.forgetConnection()
                }
            } footer: {
                Text("Entfernt lokale Schlüsselbunddaten. Home Assistant selbst wird nicht verändert.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Mehr")
        .fullScreenCover(isPresented: $isPresentingOwnerArea) {
            AdminAreaView()
        }
    }
}

private struct DiagnosticsView: View {
    let appModel: AppModel

    var body: some View {
        List {
            Section("Verbindung") {
                LabeledContent("Status", value: appModel.connectionState.statusText)
                LabeledContent("Geladene Entitäten", value: "\(appModel.entities.count)")
                LabeledContent(
                    "Nicht erreichbar",
                    value: "\(appModel.entities.filter { !$0.isAvailable }.count)"
                )
            }
            Section("Datenschutz") {
                Label("Tokens werden nie in der Diagnose angezeigt.", systemImage: "lock.shield.fill")
                Label("Keine Home-Assistant-Konfiguration wird verändert.", systemImage: "checkmark.shield.fill")
            }
        }
        .navigationTitle("Diagnose")
        .navigationBarTitleDisplayMode(.inline)
    }
}
