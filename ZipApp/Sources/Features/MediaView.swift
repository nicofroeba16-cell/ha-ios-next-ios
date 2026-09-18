import SwiftUI

struct MediaView: View {
    let appModel: AppModel

    var body: some View {
        List {
            Section("Wiedergabe") {
                let players = appModel.entities(inDomain: "media_player")
                if players.isEmpty {
                    EmptyFeatureView(
                        title: "Keine Medienplayer",
                        symbol: "play.tv",
                        message: "Verbundene Home-Assistant-Medienplayer erscheinen hier automatisch."
                    )
                } else {
                    ForEach(players) { player in
                        NavigationLink {
                            MediaDetailView(playerID: player.entityID, appModel: appModel)
                        } label: {
                            EntityRow(entity: player)
                        }
                    }
                }
            }
        }
        .navigationTitle("Medien")
    }
}

private struct MediaDetailView: View {
    let playerID: String
    let appModel: AppModel

    private var player: HomeAssistantEntity? {
        appModel.entities.first { $0.entityID == playerID }
    }

    var body: some View {
        List {
            if let player {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.tint)
                        Text(player.mediaTitle ?? player.displayName)
                            .font(.title3.weight(.semibold))
                        if let artist = player.mediaArtist {
                            Text(artist).foregroundStyle(.secondary)
                        }
                        Text(player.state.localizedCapitalized)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                Section("Steuerung") {
                    HStack {
                        mediaButton("backward.end.fill", "Vorheriger Titel") {
                            Task { await appModel.callService(for: player, service: "media_previous_track") }
                        }
                        Spacer()
                        mediaButton(player.state == "playing" ? "pause.fill" : "play.fill", "Wiedergabe") {
                            let service = player.state == "playing" ? "media_pause" : "media_play"
                            Task { await appModel.callService(for: player, service: service) }
                        }
                        Spacer()
                        mediaButton("forward.end.fill", "Nächster Titel") {
                            Task { await appModel.callService(for: player, service: "media_next_track") }
                        }
                    }
                    .padding(.horizontal)
                    if let volume = player.volumeLevel {
                        VolumeControl(value: volume) { newValue in
                            Task { await appModel.setVolume(newValue, for: player) }
                        }
                    }
                    Button(player.isMuted == true ? "Ton einschalten" : "Stummschalten") {
                        Task {
                            await appModel.callService(
                                for: player,
                                service: "volume_mute",
                                data: ["is_volume_muted": player.isMuted != true]
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Jetzt läuft")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mediaButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 52, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct VolumeControl: View {
    @State private var value: Double
    let onCommit: (Double) -> Void

    init(value: Double, onCommit: @escaping (Double) -> Void) {
        _value = State(initialValue: value)
        self.onCommit = onCommit
    }

    var body: some View {
        HStack {
            Image(systemName: "speaker.fill")
            Slider(value: $value, in: 0 ... 1) { editing in
                if !editing { onCommit(value) }
            }
            Image(systemName: "speaker.wave.3.fill")
        }
        .accessibilityLabel("Lautstärke")
    }
}
