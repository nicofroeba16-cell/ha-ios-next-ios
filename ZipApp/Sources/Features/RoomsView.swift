import SwiftUI

struct RoomsView: View {
    let appModel: AppModel

    var body: some View {
        List {
            Section {
                LabeledContent("Räume", value: "\(appModel.areas.count)")
                LabeledContent("Geräte", value: "\(appModel.devices.count)")
            }

            Section("Räume") {
                if appModel.areas.isEmpty {
                    EmptyFeatureView(
                        title: "Keine Räume geladen",
                        symbol: "door.left.hand.open",
                        message: "Home-Assistant-Areas erscheinen hier nach der Verbindung."
                    )
                } else {
                    ForEach(appModel.areas.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { area in
                        NavigationLink {
                            RoomDetailView(area: area, appModel: appModel)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(area.name, systemImage: "door.left.hand.open")
                                    .font(.body.weight(.medium))
                                Text("\(appModel.devices(inArea: area.id).count) Geräte · \(appModel.entities(inArea: area.id).count) Entitäten")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 48)
                        }
                    }
                }
            }

            if !appModel.unassignedDevices.isEmpty {
                Section("Ohne Raum") {
                    NavigationLink {
                        DeviceCollectionView(
                            title: "Geräte ohne Raum",
                            devices: appModel.unassignedDevices,
                            appModel: appModel
                        )
                    } label: {
                        Label("\(appModel.unassignedDevices.count) Geräte", systemImage: "square.grid.2x2")
                    }
                }
            }
        }
        .navigationTitle("Räume & Geräte")
    }
}

private struct RoomDetailView: View {
    let area: HomeAssistantArea
    let appModel: AppModel

    var body: some View {
        let devices = appModel.devices(inArea: area.id)
        let directEntities = appModel.directlyAssignedEntities(inArea: area.id)

        List {
            Section("Geräte") {
                if devices.isEmpty {
                    Text("Keine Geräte direkt diesem Raum zugeordnet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(devices) { device in
                        NavigationLink {
                            DeviceDetailView(device: device, appModel: appModel)
                        } label: {
                            DeviceRow(device: device, entityCount: appModel.entities(forDevice: device.id).count)
                        }
                    }
                }
            }

            if !directEntities.isEmpty {
                Section("Direkt zugeordnete Entitäten") {
                    ForEach(directEntities) { entity in
                        NavigationLink {
                            EntityControlView(entityID: entity.entityID, appModel: appModel)
                        } label: {
                            EntityRow(entity: entity)
                        }
                    }
                }
            }
        }
        .navigationTitle(area.name)
    }
}

private struct DeviceCollectionView: View {
    let title: String
    let devices: [HomeAssistantDevice]
    let appModel: AppModel

    var body: some View {
        List(devices) { device in
            NavigationLink {
                DeviceDetailView(device: device, appModel: appModel)
            } label: {
                DeviceRow(device: device, entityCount: appModel.entities(forDevice: device.id).count)
            }
        }
        .navigationTitle(title)
    }
}

private struct DeviceDetailView: View {
    let device: HomeAssistantDevice
    let appModel: AppModel

    var body: some View {
        let entities = appModel.entities(forDevice: device.id)
        List {
            Section("Gerät") {
                LabeledContent("Name", value: device.name)
                if let areaID = device.areaID,
                   let area = appModel.areas.first(where: { $0.id == areaID }) {
                    LabeledContent("Raum", value: area.name)
                } else {
                    LabeledContent("Raum", value: "Nicht zugeordnet")
                }
                LabeledContent("Entitäten", value: "\(entities.count)")
            }

            Section("Entitäten") {
                if entities.isEmpty {
                    Text("Für dieses Gerät sind aktuell keine aktiven Entitäten geladen.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entities) { entity in
                        NavigationLink {
                            EntityControlView(entityID: entity.entityID, appModel: appModel)
                        } label: {
                            EntityRow(entity: entity)
                        }
                    }
                }
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DeviceRow: View {
    let device: HomeAssistantDevice
    let entityCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .frame(width: 30)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.body.weight(.medium))
                Text("\(entityCount) Entitäten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 46)
        .accessibilityElement(children: .combine)
    }
}
