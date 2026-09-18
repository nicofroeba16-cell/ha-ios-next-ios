import SwiftUI

struct RoomsView: View {
    let appModel: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    HomeMetricTile(title: "Räume", value: "\(appModel.areas.count)", icon: "square.grid.2x2.fill", tint: .blue)
                    HomeMetricTile(title: "Geräte", value: "\(appModel.devices.count)", icon: "cpu.fill", tint: .indigo)
                }
                .padding(.horizontal, 6)
                .ios27ContentSurface(radius: 24)

                IOS27SectionHeader(title: "Räume", subtitle: "Bereiche und zugeordnete Geräte")

                if appModel.areas.isEmpty {
                    EmptyFeatureView(
                        title: "Keine Räume geladen",
                        symbol: "door.left.hand.open",
                        message: "Home-Assistant-Areas erscheinen hier nach der Verbindung."
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(appModel.areas.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { area in
                            NavigationLink {
                                RoomDetailView(area: area, appModel: appModel)
                            } label: {
                                IOS27StatusCard(
                                    title: area.name,
                                    value: "\(appModel.devices(inArea: area.id).count) Geräte · \(appModel.entities(inArea: area.id).count) Entitäten",
                                    symbol: "door.left.hand.open",
                                    tint: .blue,
                                    detail: "\(appModel.entities(inArea: area.id).filter(\.isOn).count) aktiv"
                                )
                            }
                            .buttonStyle(IOS27PressStyle())
                        }
                    }
                }

                if !appModel.unassignedDevices.isEmpty {
                    IOS27SectionHeader(title: "Ohne Raum", subtitle: "Noch nicht zugeordnet")
                    NavigationLink {
                        DeviceCollectionView(
                            title: "Geräte ohne Raum",
                            devices: appModel.unassignedDevices,
                            appModel: appModel
                        )
                    } label: {
                        IOS27StatusCard(
                            title: "Geräte ohne Raum",
                            value: "\(appModel.unassignedDevices.count) Geräte",
                            symbol: "square.grid.2x2",
                            tint: .orange
                        )
                    }
                    .buttonStyle(IOS27PressStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(IOS27HomeBackground())
        .navigationTitle("Räume")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct RoomDetailView: View {
    let area: HomeAssistantArea
    let appModel: AppModel

    private var roomEntities: [HomeAssistantEntity] { appModel.entities(inArea: area.id) }
    private var lights: [HomeAssistantEntity] { roomEntities.filter { $0.domain == "light" || ($0.domain == "switch" && $0.displayName.localizedCaseInsensitiveContains("licht")) } }
    private var media: [HomeAssistantEntity] { roomEntities.filter { $0.domain == "media_player" } }
    private var otherControls: [HomeAssistantEntity] {
        roomEntities.filter { entity in
            !lights.contains(entity) && !media.contains(entity) && entity.controlKind != .readOnly
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                IOS27StatusCard(
                    title: area.name,
                    value: "\(appModel.devices(inArea: area.id).count) Geräte · \(roomEntities.count) Entitäten",
                    symbol: "door.left.hand.open",
                    tint: .blue,
                    detail: "\(roomEntities.filter(\.isOn).count) aktiv"
                )

                if !otherControls.isEmpty {
                    IOS27SectionHeader(title: "Steuerung", subtitle: "Primäre Raumaktionen")
                    ForEach(otherControls) { entity in
                        NavigationLink {
                            EntityControlView(entityID: entity.entityID, appModel: appModel)
                        } label: {
                            IOS27StatusCard(
                                title: entity.displayName,
                                value: entity.secondaryStateText,
                                symbol: entity.iconName,
                                tint: entity.isOn ? .green : .secondary
                            )
                        }
                        .buttonStyle(IOS27PressStyle())
                    }
                }

                if !lights.isEmpty {
                    IOS27SectionHeader(title: "Licht", subtitle: "Direkte Raumsteuerung")
                    ForEach(lights) { entity in
                        IOS27LightCard(entity: entity, appModel: appModel)
                    }
                }

                if !media.isEmpty {
                    IOS27SectionHeader(title: "Medien", subtitle: "Player und Receiver")
                    ForEach(media) { entity in
                        IOS27MediaCard(
                            player: entity,
                            appModel: appModel,
                            volumePlayer: volumePlayer(for: entity)
                        )
                    }
                }

                let devices = appModel.devices(inArea: area.id)
                if !devices.isEmpty {
                    IOS27SectionHeader(title: "Technische Details", subtitle: "Geräte und Entitäten")
                    DisclosureGroup("Geräte (\(devices.count))") {
                        VStack(spacing: 0) {
                            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                                NavigationLink {
                                    DeviceDetailView(device: device, appModel: appModel)
                                } label: {
                                    DeviceRow(device: device, entityCount: appModel.entities(forDevice: device.id).count)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                }
                                .buttonStyle(.plain)
                                if index != devices.indices.last { Divider().padding(.leading, 56) }
                            }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(14)
                    .ios27ContentSurface(radius: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(IOS27HomeBackground())
        .navigationTitle(area.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func volumePlayer(for entity: HomeAssistantEntity) -> HomeAssistantEntity? {
        guard entity.entityID == "media_player.nico_zimmer_untergeschoss_apple_tv" else { return nil }
        return appModel.entities.first { $0.entityID == "media_player.denon_avr_x1300w" }
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
        .navigationBarTitleDisplayMode(.inline)
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
