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
                Button("Verbindung verwalten") { appModel.isPresentingConnection = true }
                Button("Daten aktualisieren") { Task { await appModel.refresh() } }
                    .disabled(isBusy)
                Button("Verbindung entfernen", role: .destructive) { appModel.forgetConnection() }
            }
            if let error = appModel.lastActionError {
                Section("Letzter Aktionsfehler") { Text(error).foregroundStyle(.red) }
            }
            Section("Live-HA-Inventar") {
                LabeledContent("Entitäten", value: "\(appModel.entities.count)")
                LabeledContent("Räume", value: "\(appModel.areas.count)")
                LabeledContent("Geräte", value: "\(appModel.devices.count)")
                NavigationLink("Alle Entitäten") {
                    EntityCatalogView(title: "Alle Entitäten", entities: appModel.entities, appModel: appModel)
                }
                NavigationLink("Aktionen & Dienste") {
                    EntityCatalogView(title: "Aktionen & Dienste", entities: appModel.serviceLikeEntities, appModel: appModel)
                }
                NavigationLink("Entitäten ohne Raum") {
                    EntityCatalogView(title: "Ohne Raum", entities: appModel.unassignedEntities, appModel: appModel)
                }
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

private struct EntityCatalogView: View {
    let title: String
    let entities: [HomeAssistantEntity]
    let appModel: AppModel

    var body: some View {
        List {
            ForEach(groupedDomains, id: \.domain) { group in
                Section(group.domain) {
                    ForEach(group.entities) { entity in
                        NavigationLink {
                            EntityControlView(entityID: entity.entityID, appModel: appModel)
                        } label: {
                            EntityRow(entity: entity)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var groupedDomains: [(domain: String, entities: [HomeAssistantEntity])] {
        Dictionary(grouping: entities, by: \.domain)
            .map { domain, entities in
                (domain, entities.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending })
            }
            .sorted { $0.domain < $1.domain }
    }
}
