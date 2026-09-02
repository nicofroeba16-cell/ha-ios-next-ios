import SwiftUI

struct HomeView: View {
    let appModel: AppModel

    var body: some View {
        List {
            Section {
                Picker("Profil", selection: Bindable(appModel).selectedProfile) {
                    ForEach(HomeProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                .pickerStyle(.menu)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appModel.selectedProfile.primaryArea)
                            .font(.title3.weight(.semibold))
                        Text(appModel.selectedProfile.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ConnectionStatusLabel(state: appModel.connectionState)
                }
                .padding(.vertical, 4)
            }
            Section("Favoriten") {
                if appModel.profileFavorites.isEmpty {
                    EmptyFeatureView(title: "Noch keine Favoriten", symbol: "star", message: "Für dieses Profil sind noch keine bestätigten Geräte hinterlegt.")
                } else {
                    ForEach(appModel.profileFavorites) { entity in
                        EntityRow(entity: entity) {
                            Task { await appModel.toggle(entity) }
                        }
                    }
                }
            }
            Section("Übersicht") {
                Label("\(appModel.entities(inDomain: "light").filter(\.isOn).count) Lichter aktiv", systemImage: "lightbulb.fill")
                Label("\(appModel.entities(inDomain: "media_player").filter(\.isOn).count) Medien aktiv", systemImage: "play.tv.fill")
            }
        }
        .navigationTitle("Zuhause")
    }
}

#Preview("Verbunden") {
    HomeView(appModel: .preview)
}
