import SwiftUI

struct MediaView: View {
    let appModel: AppModel

    var body: some View {
        List {
            Section("Wiedergabe") {
                let players = appModel.entities(inDomain: "media_player")
                if players.isEmpty {
                    EmptyFeatureView(title: "Keine Medien aktiv", symbol: "play.tv", message: "Verbundene Home-Assistant-Medienplayer erscheinen hier automatisch.")
                } else {
                    ForEach(players) { player in
                        NavigationLink {
                            MediaDetailView(player: player)
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
    let player: HomeAssistantEntity

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(player.displayName).font(.title2.weight(.semibold))
            Text(player.state.localizedCapitalized).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Jetzt läuft")
        .navigationBarTitleDisplayMode(.inline)
    }
}
