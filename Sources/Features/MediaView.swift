import SwiftUI

struct MediaView: View {
    let appModel: AppModel

    private var players: [HomeAssistantEntity] {
        appModel.entities(inDomain: "media_player")
    }

    var body: some View {
        IOSNextPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.pageSpacing) {
                IOSNextSectionHeader(
                    title: "Medien",
                    subtitle: activeSubtitle,
                    symbol: "play.tv.fill"
                )

                if players.isEmpty {
                    EmptyFeatureView(
                        title: "Keine Medienplayer",
                        symbol: "play.tv",
                        message: "Verbundene Home-Assistant-Medienplayer erscheinen hier automatisch."
                    )
                    .iosNextCard()
                } else {
                    ForEach(players) { player in
                        NavigationLink {
                            EntityDetailView(entityID: player.entityID, appModel: appModel)
                        } label: {
                            mediaCard(player)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("media-player-link-\(player.entityID)")
                    }
                }
            }
        }
        .navigationTitle("Medien")
        .refreshable { await appModel.refresh() }
    }

    private func mediaCard(_ player: HomeAssistantEntity) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.purple.opacity(0.13))
                Image(systemName: player.state == "playing" ? "waveform" : "play.rectangle.fill")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.purple)
                    .symbolEffect(.variableColor.iterative, isActive: player.state == "playing")
            }
            .frame(width: 68, height: 68)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.mediaTitle ?? player.displayName)
                    .font(.headline)
                    .lineLimit(2)
                Text(player.mediaArtist ?? player.source ?? player.stateDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward").foregroundStyle(.tertiary)
        }
        .padding(18)
        .iosNextCard()
        .accessibilityElement(children: .combine)
    }

    private var activeSubtitle: String {
        let active = players.filter(\.isOn).count
        return active == 1 ? "1 Player ist aktiv" : "\(active) Player sind aktiv"
    }
}
