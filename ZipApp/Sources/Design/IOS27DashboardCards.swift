import SwiftUI

struct IOS27SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.bold))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IOS27LightCard: View {
    let entity: HomeAssistantEntity
    let appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(entity.isOn ? .yellow : .secondary)
                    .frame(width: 42, height: 42)
                    .background((entity.isOn ? Color.yellow : Color.secondary).opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(entity.displayName).font(.headline)
                    Text(entity.isOn ? "Eingeschaltet" : "Ausgeschaltet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await appModel.toggle(entity) }
                } label: {
                    Image(systemName: "power")
                        .font(.headline.weight(.semibold))
                        .frame(width: 42, height: 42)
                }
                .ios27GlassButton()
                .tint(entity.isOn ? .yellow : .secondary)
                .accessibilityLabel(entity.isOn ? "Ausschalten" : "Einschalten")
            }

            if let brightness = entity.brightness {
                HStack(spacing: 10) {
                    Image(systemName: "sun.min.fill").foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { min(max(brightness / 255, 0), 1) },
                        set: { value in Task { await appModel.setBrightness(value, for: entity) } }
                    ))
                    Image(systemName: "sun.max.fill").foregroundStyle(entity.isOn ? .yellow : .secondary)
                }
            }
        }
        .padding(16)
        .ios27ContentSurface(radius: 24)
    }
}

struct IOS27MediaCard: View {
    let player: HomeAssistantEntity
    let appModel: AppModel
    var volumePlayer: HomeAssistantEntity? = nil

    private var effectiveVolumePlayer: HomeAssistantEntity { volumePlayer ?? player }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "play.tv.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.13), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.displayName).font(.headline)
                    Text(player.mediaTitle ?? player.state.localizedCapitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(player.state.localizedCapitalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(player.state == "playing" ? .green : .secondary)
            }

            IOS27GlassControlGroup(spacing: 18) {
                HStack(spacing: 18) {
                    mediaButton("backward.end.fill", "Vorheriger Titel", "media_previous_track")
                    mediaButton(player.state == "playing" ? "pause.fill" : "play.fill", "Wiedergabe", player.state == "playing" ? "media_pause" : "media_play", prominent: true)
                    mediaButton("forward.end.fill", "Nächster Titel", "media_next_track")
                }
                .frame(maxWidth: .infinity)
            }

            if let volume = effectiveVolumePlayer.volumeLevel {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { volume },
                        set: { value in Task { await appModel.setVolume(value, for: effectiveVolumePlayer) } }
                    ))
                    Button {
                        Task {
                            await appModel.callService(
                                for: effectiveVolumePlayer,
                                service: "volume_mute",
                                data: ["is_volume_muted": effectiveVolumePlayer.isMuted != true]
                            )
                        }
                    } label: {
                        Image(systemName: effectiveVolumePlayer.isMuted == true ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    .ios27GlassButton()
                }
            }
        }
        .padding(16)
        .ios27ContentSurface(radius: 24)
    }

    private func mediaButton(_ symbol: String, _ label: String, _ service: String, prominent: Bool = false) -> some View {
        Button {
            Task { await appModel.callService(for: player, service: service) }
        } label: {
            Image(systemName: symbol)
                .font(prominent ? .title2.weight(.semibold) : .headline)
                .frame(width: prominent ? 54 : 44, height: prominent ? 54 : 44)
        }
        .ios27GlassButton(prominent: prominent)
        .tint(.blue)
        .accessibilityLabel(label)
    }
}

struct IOS27StatusCard: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let title: String
    let value: String
    let symbol: String
    let tint: Color
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(value).font(.caption).foregroundStyle(.secondary)
                if let detail { Text(detail).font(.caption2).foregroundStyle(colorSchemeContrast == .increased ? .secondary : .tertiary) }
            }
            Spacer()
        }
        .padding(14)
        .ios27ContentSurface(radius: 20)
    }
}

struct IOS27MediaZoneCard: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let title: String
    let subtitle: String
    let players: [HomeAssistantEntity]
    let masterState: HomeAssistantEntity?
    let masterScript: HomeAssistantEntity?
    let appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.title3.weight(.bold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let masterState {
                    Label(masterState.isOn ? "Aktiv" : "Bereit", systemImage: masterState.isOn ? "dot.radiowaves.left.and.right" : "moon.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(masterState.isOn ? .green : .secondary)
                }
            }

            ForEach(players) { player in
                HStack(spacing: 11) {
                    Image(systemName: player.iconName)
                        .foregroundStyle(player.state == "playing" ? .blue : .secondary)
                        .frame(width: 34, height: 34)
                        .background(Color.blue.opacity(player.state == "playing" ? 0.14 : 0.06), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.displayName).font(.subheadline.weight(.semibold))
                        Text(player.mediaTitle ?? player.state.localizedCapitalized)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(player.state.localizedCapitalized)
                        .font(.caption2)
                        .foregroundStyle(colorSchemeContrast == .increased ? .secondary : .tertiary)
                }
            }

            if let masterScript {
                Button {
                    Task { await appModel.activateScript(masterScript) }
                } label: {
                    Label("Medien Master", systemImage: "power.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .ios27GlassButton(prominent: true)
                .tint(.blue)
            }
        }
        .padding(18)
        .ios27ContentSurface(radius: 28, elevated: true)
    }
}

struct IOS27FireTVCompanionCard: View {
    let player: HomeAssistantEntity
    let appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 13) {
                Image(systemName: "tv.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 48, height: 48)
                    .background(Color.orange.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.displayName).font(.title3.weight(.bold))
                    Text(player.mediaTitle ?? player.state.localizedCapitalized)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Circle()
                    .fill(player.isAvailable ? (player.isOn ? Color.green : Color.secondary) : Color.red)
                    .frame(width: 8, height: 8)
            }

            IOS27GlassControlGroup(spacing: 12) {
                HStack(spacing: 12) {
                    companionButton("power", "Power") {
                        Task { await appModel.callService(for: player, service: player.isOn ? "turn_off" : "turn_on") }
                    }
                    companionButton("gobackward.10", "10 Sekunden zurück") {
                        Task { await appModel.seekRelative(-10, for: player) }
                    }
                    companionButton(player.state == "playing" ? "pause.fill" : "play.fill", "Wiedergabe", prominent: true) {
                        Task { await appModel.callService(for: player, service: player.state == "playing" ? "media_pause" : "media_play") }
                    }
                    companionButton("goforward.10", "10 Sekunden vor") {
                        Task { await appModel.seekRelative(10, for: player) }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                capabilityChip("Player", "play.fill")
                capabilityChip("Apps", "square.grid.2x2.fill")
                capabilityChip("Remote", "remote.fill")
                capabilityChip("Queue", "list.bullet")
            }

            if let volume = player.volumeLevel {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { volume },
                        set: { value in Task { await appModel.setVolume(value, for: player) } }
                    ))
                    Button {
                        Task { await appModel.callService(for: player, service: "volume_mute", data: ["is_volume_muted": player.isMuted != true]) }
                    } label: {
                        Image(systemName: player.isMuted == true ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    .ios27GlassButton()
                }
            }
        }
        .padding(18)
        .ios27ContentSurface(radius: 28, elevated: true)
    }

    private func companionButton(_ symbol: String, _ label: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(prominent ? .title2.weight(.semibold) : .headline)
                .frame(width: prominent ? 52 : 44, height: prominent ? 52 : 44)
        }
        .ios27GlassButton(prominent: prominent)
        .tint(.orange)
        .accessibilityLabel(label)
    }

    private func capabilityChip(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}
