import SwiftUI

struct MediaView: View {
    let appModel: AppModel

    private var players: [HomeAssistantEntity] { appModel.entities(inDomain: "media_player") }
    private var nicoPlayers: [HomeAssistantEntity] {
        [
            entity("media_player.nico_zimmer_untergeschoss_apple_tv"),
            entity("media_player.denon_avr_x1300w"),
            entity("media_player.playstation_5")
        ].compactMap { $0 }
    }
    private var nicoIDs: Set<String> { Set(nicoPlayers.map(\.entityID)) }
    private var fireTVPlayers: [HomeAssistantEntity] { players.filter { $0.entityID.contains("fire_tv_companion") } }
    private var fireTVIDs: Set<String> { Set(fireTVPlayers.map(\.entityID)) }
    private var remainingPlayers: [HomeAssistantEntity] {
        players.filter { !nicoIDs.contains($0.entityID) && !fireTVIDs.contains($0.entityID) && $0.entityID != "media_player.nico_medien" }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if !nicoPlayers.isEmpty {
                    IOS27SectionHeader(title: "Nico Medien", subtitle: "Apple TV · Denon · PlayStation")
                    IOS27MediaZoneCard(
                        title: "Nico Medien",
                        subtitle: "Gemeinsame Medienzone",
                        players: nicoPlayers,
                        masterState: entity("binary_sensor.nico_medien_aktiv") ?? entity("binary_sensor.nico_medien_aktiv_2"),
                        masterScript: entity("script.nico_medien_master_zentrale"),
                        appModel: appModel
                    )
                }

                if !fireTVPlayers.isEmpty {
                    IOS27SectionHeader(title: "Fire TV Companion", subtitle: "Capability-basierte Steuerung")
                    ForEach(fireTVPlayers) { player in
                        IOS27FireTVCompanionCard(player: player, appModel: appModel)
                    }
                }

                if !remainingPlayers.isEmpty {
                    IOS27SectionHeader(title: "Weitere Medien", subtitle: "Receiver, Cast und TV")
                    ForEach(remainingPlayers) { player in
                        NavigationLink {
                            MediaDetailView(playerID: player.entityID, appModel: appModel)
                        } label: {
                            IOS27MediaCard(player: player, appModel: appModel)
                        }
                        .buttonStyle(IOS27PressStyle())
                    }
                }

                if players.isEmpty {
                    EmptyFeatureView(
                        title: "Keine Medienplayer",
                        symbol: "play.tv",
                        message: "Verbundene Home-Assistant-Medienplayer erscheinen hier automatisch."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(IOS27HomeBackground())
        .navigationTitle("Medien")
    }

    private func entity(_ id: String) -> HomeAssistantEntity? {
        appModel.entities.first { $0.entityID == id }
    }
}

struct MediaDetailView: View {
    let playerID: String
    let appModel: AppModel

    private var player: HomeAssistantEntity? { appModel.entities.first { $0.entityID == playerID } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let player {
                    IOS27MediaCard(player: player, appModel: appModel)
                } else {
                    EmptyFeatureView(
                        title: "Player nicht verfügbar",
                        symbol: "play.slash",
                        message: "Der Player ist nicht mehr im aktuellen Home-Assistant-Zustand vorhanden."
                    )
                }
            }
            .padding(16)
        }
        .background(IOS27HomeBackground())
        .navigationTitle(player?.displayName ?? "Jetzt läuft")
        .navigationBarTitleDisplayMode(.inline)
    }
}
