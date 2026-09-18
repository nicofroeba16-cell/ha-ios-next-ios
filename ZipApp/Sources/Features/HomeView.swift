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
                        NavigationLink {
                            EntityControlView(entityID: entity.entityID, appModel: appModel)
                        } label: {
                            EntityRow(entity: entity)
                        }
                    }
                }
            }
            Section("Übersicht") {
                Label("\(appModel.entities(inDomain: "light").filter(\.isOn).count) Lichter aktiv", systemImage: "lightbulb.fill")
                Label("\(appModel.entities(inDomain: "media_player").filter(\.isOn).count) Medien aktiv", systemImage: "play.tv.fill")
                Label("\(appModel.areas.count) Räume", systemImage: "door.left.hand.open")
                let unavailable = appModel.entities.filter { !$0.isAvailable }.count
                if unavailable > 0 {
                    Label("\(unavailable) nicht verfügbar", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            if let error = appModel.lastActionError {
                Section("Letzte Aktion") {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Zuhause")
    }
}

#Preview("Verbunden") {
    HomeView(appModel: .preview)
}
