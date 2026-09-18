import SwiftUI

struct SystemView: View {
    let appModel: AppModel

    private var warningEntities: [HomeAssistantEntity] {
        appModel.entities.filter { entity in
            let id = entity.entityID.lowercased()
            return id.contains("warnung") && !id.contains("quittiert")
        }
    }

    private var acknowledgedWarnings: [HomeAssistantEntity] {
        appModel.entities.filter { $0.entityID.lowercased().contains("warnung_quittiert") }
    }

    private var updateEntities: [HomeAssistantEntity] {
        appModel.entities.filter { $0.domain == "update" }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                IOS27SectionHeader(title: "Verbindung", subtitle: "Home Assistant")
                connectionCard

                IOS27SectionHeader(title: "Inventar", subtitle: "Live aus Home Assistant")
                inventoryStrip

                IOS27SectionHeader(title: "Systemwarnungen", subtitle: "Technischer Zustand und Quittierung")
                warningCenter

                if !updateEntities.isEmpty {
                    IOS27SectionHeader(title: "Updates")
                    ForEach(updateEntities.prefix(6)) { entity in
                        IOS27StatusCard(
                            title: entity.displayName,
                            value: entity.secondaryStateText,
                            symbol: "arrow.down.circle.fill",
                            tint: entity.isOn ? .orange : .green
                        )
                    }
                }

                IOS27SectionHeader(title: "Diagnose", subtitle: "Technische Ebenen")
                diagnosticsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(IOS27HomeBackground())
        .navigationTitle("System")
    }

    private var connectionCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Home Assistant", systemImage: "house.fill")
                    .font(.headline)
                Spacer()
                HomeConnectionPill(state: appModel.connectionState)
            }
            Divider()
            HStack(spacing: 12) {
                Button("Verwalten") { appModel.isPresentingConnection = true }
                    .ios27GlassButton()
                Button("Aktualisieren") { Task { await appModel.refresh() } }
                    .ios27GlassButton(prominent: true)
                    .disabled(isBusy)
                Spacer()
            }
            if let error = appModel.lastActionError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .ios27Surface(radius: 24, tint: appModel.isConnected ? .green : .orange)
    }

    private var inventoryStrip: some View {
        HStack(spacing: 0) {
            HomeMetricTile(title: "Entitäten", value: "\(appModel.entities.count)", icon: "circle.grid.3x3.fill", tint: .blue)
            Divider().frame(height: 54)
            HomeMetricTile(title: "Räume", value: "\(appModel.areas.count)", icon: "square.grid.2x2.fill", tint: .indigo)
            Divider().frame(height: 54)
            HomeMetricTile(title: "Geräte", value: "\(appModel.devices.count)", icon: "cpu.fill", tint: .purple)
        }
        .padding(.horizontal, 6)
        .ios27Surface(radius: 24)
    }

    private var warningCenter: some View {
        VStack(spacing: 10) {
            if warningEntities.isEmpty {
                IOS27StatusCard(
                    title: "Keine Warnungen",
                    value: "Aktuell kein Warnstatus geladen",
                    symbol: "checkmark.shield.fill",
                    tint: .green
                )
            } else {
                ForEach(warningEntities.prefix(8)) { warning in
                    let active = warning.isOn || warning.state == "problem"
                    IOS27StatusCard(
                        title: warning.displayName,
                        value: active ? "Aktiv" : warning.secondaryStateText,
                        symbol: active ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                        tint: active ? .orange : .green,
                        detail: acknowledgementText(for: warning)
                    )
                }
            }
        }
    }

    private var diagnosticsCard: some View {
        VStack(spacing: 0) {
            diagnosticLink("Alle Entitäten", "list.bullet.rectangle", appModel.entities)
            Divider().padding(.leading, 48)
            diagnosticLink("Aktionen & Dienste", "bolt.fill", appModel.serviceLikeEntities)
            Divider().padding(.leading, 48)
            diagnosticLink("Entitäten ohne Raum", "questionmark.folder.fill", appModel.unassignedEntities)
            Divider().padding(.leading, 48)
            Button(role: .destructive) { appModel.forgetConnection() } label: {
                Label("Verbindung entfernen", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 14)
        .ios27Surface(radius: 24)
    }

    private func diagnosticLink(_ title: String, _ symbol: String, _ entities: [HomeAssistantEntity]) -> some View {
        NavigationLink {
            EntityCatalogView(title: title, entities: entities, appModel: appModel)
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Text("\(entities.count)").foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func acknowledgementText(for warning: HomeAssistantEntity) -> String? {
        let root = warning.entityID
            .replacingOccurrences(of: "binary_sensor.", with: "")
            .replacingOccurrences(of: "sensor.", with: "")
            .replacingOccurrences(of: "_warnung", with: "")
        let match = acknowledgedWarnings.first { $0.entityID.contains(root) }
        guard let match else { return nil }
        return match.isOn ? "Quittiert" : "Nicht quittiert"
    }

    private var isBusy: Bool {
        switch appModel.connectionState {
        case .connecting, .reconnecting: true
        default: false
        }
    }
}

struct EntityCatalogView: View {
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
