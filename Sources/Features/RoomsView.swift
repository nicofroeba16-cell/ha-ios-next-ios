import SwiftUI

struct RoomsView: View {
    let appModel: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    HomeMetricTile(title: "Räume", value: "\(appModel.areas.filter(\.isAppRoom).count)", icon: "square.grid.2x2.fill", tint: .blue)
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
                        ForEach(appModel.areas.filter(\.isAppRoom).sorted { $0.appDisplayName.localizedStandardCompare($1.appDisplayName) == .orderedAscending }) { area in
                            NavigationLink {
                                RoomDetailView(area: area, appModel: appModel)
                            } label: {
                                IOS27StatusCard(
                                    title: area.appDisplayName,
                                    value: "\(appModel.devices(inArea: area.id).count) Geräte",
                                    symbol: "door.left.hand.open",
                                    tint: .blue,
                                    detail: "\(appModel.entities(inArea: area.id).filter(\.isOn).count) aktiv"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !appModel.unassignedDevices.isEmpty {
                    IOS27SectionHeader(title: "Technische Details", subtitle: "Nicht zugeordnete Geräte")
                    DisclosureGroup("Geräte ohne Raum (\(appModel.unassignedDevices.count))") {
                        NavigationLink {
                            DeviceCollectionView(
                                title: "Geräte ohne Raum",
                                devices: appModel.unassignedDevices,
                                appModel: appModel
                            )
                        } label: {
                            Label("Geräte anzeigen", systemImage: "square.grid.2x2")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .ios27ContentSurface(radius: 24)
                }

            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .ios27ScrollBottomClearance()
        .background(IOS27HomeBackground())
        .navigationTitle("Räume")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct RoomDetailView: View {
    let area: HomeAssistantArea
    let appModel: AppModel

    private var roomEntities: [HomeAssistantEntity] { appModel.entities(inArea: area.id) }
    private var isNicoRoom: Bool { area.name.localizedCaseInsensitiveCompare("Nico Zimmer") == .orderedSame }
    private var isHuetteRoom: Bool { area.name.localizedCaseInsensitiveCompare("Hütte Master") == .orderedSame || area.name.localizedCaseInsensitiveCompare("Hütte") == .orderedSame }
    private var lights: [HomeAssistantEntity] {
        if isNicoRoom {
            let order = [
                "light.kronach_fernseher_links",
                "light.kronach_fernseher_rechts",
                "light.kronach_schrank",
                "switch.schreibtisch_rgb_standlampe_steckdose_1"
            ]
            return order.compactMap(entity)
        }
        if isHuetteRoom {
            return ["light.hutte", "light.tisch_tisch"].compactMap(entity)
        }
        return roomEntities.filter { $0.domain == "light" || ($0.domain == "switch" && $0.displayName.localizedCaseInsensitiveContains("licht")) }
    }
    private var media: [HomeAssistantEntity] {
        if isNicoRoom {
            return [
                "media_player.nico_zimmer_untergeschoss_apple_tv",
                "media_player.denon_avr_x1300w",
                "media_player.playstation_5"
            ].compactMap(entity)
        }
        if isHuetteRoom {
            return ["media_player.denon_avr_x1800h", "media_player.gigatv_home"].compactMap(entity)
        }
        return roomEntities.filter { $0.domain == "media_player" }
    }
    private var otherControls: [HomeAssistantEntity] {
        guard !isNicoRoom && !isHuetteRoom else { return [] }
        return roomEntities.filter { entity in
            !lights.contains(entity) && !media.contains(entity) && entity.isPrimaryRoomControl
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if isNicoRoom {
                    NicoRoomDashboardContent(appModel: appModel)
                } else if isHuetteRoom {
                    HuetteRoomDashboardContent(appModel: appModel)
                } else {
                    IOS27StatusCard(
                        title: area.appDisplayName,
                        value: "\(appModel.devices(inArea: area.id).count) Geräte",
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
                            .buttonStyle(.plain)
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
            .padding(.bottom, 24)
        }
        .ios27ScrollBottomClearance()
        .background(IOS27HomeBackground())
        .navigationTitle(area.appDisplayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entity(_ id: String) -> HomeAssistantEntity? {
        appModel.entities.first { $0.entityID == id }
    }

    private func volumePlayer(for entity: HomeAssistantEntity) -> HomeAssistantEntity? {
        guard entity.entityID == "media_player.nico_zimmer_untergeschoss_apple_tv" else { return nil }
        return appModel.entities.first { $0.entityID == "media_player.denon_avr_x1300w" }
    }
}



private struct HuetteRoomDashboardContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let appModel: AppModel

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        IOS27SectionHeader(title: "Beleuchtung", subtitle: "Ambiente · Tisch")

        ForEach(["light.hutte", "light.tisch_tisch"].compactMap(entity)) { light in
            IOS27LightCard(entity: light, appModel: appModel)
        }

        LazyVGrid(columns: columns, spacing: 12) {
            let lightMaster = entity("group.hutte_beleuchtung") ?? HomeAssistantEntity(
                entityID: "group.hutte_beleuchtung",
                state: ["light.hutte", "light.tisch_tisch"].compactMap(entity).contains(where: \.isOn) ? "on" : "off",
                attributes: [:]
            )
            NicoActionTile(
                title: "Licht Master",
                subtitle: lightMaster.isOn ? "Geräte an" : "Alles aus",
                symbol: "power",
                tint: lightMaster.isOn ? .green : .red
            ) {
                Task { await appModel.toggle(lightMaster) }
            }

            if let dimmed = entity("scene.hutte_master_tisch_gedimmt") {
                NicoActionTile(
                    title: "Tisch Gedimmt",
                    subtitle: "Szene",
                    symbol: "lamp.table.fill",
                    tint: .orange
                ) {
                    Task { await appModel.activate(dimmed) }
                }
            }
        }

        IOS27SectionHeader(title: "Medien", subtitle: "Denon · GigaTV")
        ForEach(["media_player.denon_avr_x1800h", "media_player.gigatv_home"].compactMap(entity)) { player in
            IOS27MediaCard(player: player, appModel: appModel)
        }
    }

    private func entity(_ id: String) -> HomeAssistantEntity? {
        appModel.entities.first { $0.entityID == id }
    }
}

private struct NicoRoomDashboardContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let appModel: AppModel

    private var tvLights: [HomeAssistantEntity] {
        ["light.kronach_fernseher_links", "light.kronach_fernseher_rechts"].compactMap(entity)
    }

    private var compactLights: [HomeAssistantEntity] {
        ["light.kronach_schrank", "switch.schreibtisch_rgb_standlampe_steckdose_1"].compactMap(entity)
    }

    private var mediaPlayers: [HomeAssistantEntity] {
        [
            "media_player.nico_zimmer_untergeschoss_apple_tv",
            "media_player.denon_avr_x1300w",
            "media_player.playstation_5"
        ].compactMap(entity)
    }

    private var lightMaster: HomeAssistantEntity {
        entity("group.nico_beleuchtung") ?? HomeAssistantEntity(
            entityID: "group.nico_beleuchtung",
            state: (tvLights + compactLights).contains(where: \.isOn) ? "on" : "off",
            attributes: [:]
        )
    }

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        IOS27SectionHeader(title: "Beleuchtung", subtitle: "TV · Schrank · Schreibtisch")

        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(tvLights) { light in
                NicoPrimaryLightTile(entity: light, appModel: appModel)
            }
        }

        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(compactLights) { light in
                NicoCompactControlTile(entity: light, appModel: appModel)
            }
        }

        LazyVGrid(columns: columns, spacing: 12) {
            NicoActionTile(
                title: "Licht Master",
                subtitle: lightMaster.isOn ? "Geräte an" : "Alles aus",
                symbol: "power",
                tint: lightMaster.isOn ? .green : .red
            ) {
                Task { await appModel.toggle(lightMaster) }
            }

            if let prisma = entity("scene.kronach_kronach_prisma") {
                NicoActionTile(
                    title: "Prisma",
                    subtitle: "Schrank-Effekt",
                    symbol: "paintpalette.fill",
                    tint: .purple
                ) {
                    Task { await appModel.activate(prisma) }
                }
            }
        }

        IOS27SectionHeader(title: "Medien-Center", subtitle: "Apple TV · Denon · PS5")

        LazyVGrid(columns: columns, spacing: 12) {
            if let mediaMaster = entity("script.nico_medien_master_zentrale") {
                let mediaState = entity("binary_sensor.nico_medien_aktiv")
                NicoActionTile(
                    title: "Medien Master",
                    subtitle: mediaState?.isOn == true ? "Geräte aktiv" : "Alles aus",
                    symbol: "power",
                    tint: mediaState?.isOn == true ? .green : .red
                ) {
                    Task { await appModel.activateScript(mediaMaster) }
                }
            }

            if let tvPower = entity("switch.tv_steckdose_1") {
                NicoActionTile(
                    title: "TV Steckdose",
                    subtitle: tvPower.isOn ? "Ein" : "Aus",
                    symbol: "powerplug.fill",
                    tint: tvPower.isOn ? .green : .secondary
                ) {
                    Task { await appModel.toggle(tvPower) }
                }
            }
        }

        if !mediaPlayers.isEmpty {
            IOS27MediaZoneCard(
                title: "Nico Medien",
                subtitle: "Apple TV und Denon gekoppelt · PlayStation separat",
                players: mediaPlayers,
                masterState: entity("binary_sensor.nico_medien_aktiv"),
                masterScript: nil,
                appModel: appModel
            )
        }
    }

    private func entity(_ id: String) -> HomeAssistantEntity? {
        appModel.entities.first { $0.entityID == id }
    }
}

private struct NicoPrimaryLightTile: View {
    let entity: HomeAssistantEntity
    let appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill")
                    .font(.headline)
                    .foregroundStyle(entity.isOn ? .yellow : .secondary)
                    .frame(width: 38, height: 38)
                    .background((entity.isOn ? Color.yellow : Color.secondary).opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                Spacer()
                Button {
                    Task { await appModel.toggle(entity) }
                } label: {
                    Image(systemName: "power")
                        .frame(width: 38, height: 38)
                }
                .ios27GlassButton()
                .tint(entity.isOn ? .yellow : .secondary)
                .accessibilityLabel(entity.isOn ? "Ausschalten" : "Einschalten")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entity.displayName)
                    .font(.headline)
                Text(entity.isOn ? "Eingeschaltet" : "Ausgeschaltet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let brightness = entity.brightness {
                Slider(value: Binding(
                    get: { min(max(brightness / 255, 0), 1) },
                    set: { value in Task { await appModel.setBrightness(value, for: entity) } }
                ))
                .accessibilityLabel("Helligkeit \(entity.displayName)")
                .accessibilityValue("\(Int((brightness / 255) * 100)) Prozent")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .ios27ContentSurface(radius: 24)
    }
}

private struct NicoCompactControlTile: View {
    let entity: HomeAssistantEntity
    let appModel: AppModel

    var body: some View {
        Button {
            Task { await appModel.toggle(entity) }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: entity.domain == "light" ? "lightbulb.fill" : "lamp.desk.fill")
                    .foregroundStyle(entity.isOn ? .yellow : .secondary)
                    .frame(width: 34, height: 34)
                    .background((entity.isOn ? Color.yellow : Color.secondary).opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(entity.displayName).font(.subheadline.weight(.semibold))
                    Text(entity.isOn ? "Ein" : "Aus").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(14)
            .ios27ContentSurface(radius: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entity.displayName)
        .accessibilityValue(entity.isOn ? "Ein" : "Aus")
        .accessibilityHint("Schaltet \(entity.displayName) um")
    }
}

private struct NicoActionTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .padding(14)
            .ios27ContentSurface(radius: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
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
