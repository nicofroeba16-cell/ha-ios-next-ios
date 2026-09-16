import SwiftUI

struct RoomsView: View {
    let appModel: AppModel

    var body: some View {
        IOSNextPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.pageSpacing) {
                IOSNextSectionHeader(
                    title: "Deine Räume",
                    subtitle: "Die Zuordnung folgt ausschließlich den bestätigten Profilen.",
                    symbol: "door.left.hand.open"
                )

                ForEach(appModel.profileDefinition.roomNames, id: \.self) { room in
                    NavigationLink {
                        RoomDetailView(title: room, appModel: appModel)
                    } label: {
                        roomCard(room)
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    AllEntitiesView(appModel: appModel)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Alle Entitäten")
                                .font(.headline)
                            Text("\(appModel.entities.count) geladene Entitäten durchsuchen")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward").foregroundStyle(.tertiary)
                    }
                    .padding(18)
                    .iosNextCard()
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Räume")
    }

    private func roomCard(_ room: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: roomIcon(for: room))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(room).font(.headline)
                Text(roomSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.forward").foregroundStyle(.tertiary)
        }
        .padding(18)
        .iosNextCard()
    }

    private func roomIcon(for room: String) -> String {
        room.localizedCaseInsensitiveContains("zimmer") ? "bed.double.fill" : "house.fill"
    }

    private var roomSubtitle: String {
        let count = appModel.profileFavorites.count
        return count == 1 ? "1 bestätigtes Gerät" : "\(count) bestätigte Geräte"
    }
}

private struct RoomDetailView: View {
    let title: String
    let appModel: AppModel

    var body: some View {
        IOSNextPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.pageSpacing) {
                IOSNextSectionHeader(
                    title: title,
                    subtitle: "Nur verifizierte Geräte des gewählten Profils",
                    symbol: "bed.double.fill"
                )

                VStack(spacing: 0) {
                    if appModel.profileFavorites.isEmpty {
                        EmptyFeatureView(
                            title: "Noch nicht zugeordnet",
                            symbol: "square.grid.2x2",
                            message: "Für diesen Raum wurden noch keine Home-Assistant-Entitäten bestätigt."
                        )
                    } else {
                        ForEach(appModel.profileFavorites) { entity in
                            NavigationLink {
                                EntityDetailView(entityID: entity.entityID, appModel: appModel)
                            } label: {
                                EntityRow(entity: entity)
                            }
                            .buttonStyle(.plain)
                            if entity.id != appModel.profileFavorites.last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .iosNextCard()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AllEntitiesView: View {
    let appModel: AppModel
    @State private var searchText = ""

    private var filteredEntities: [HomeAssistantEntity] {
        guard !searchText.isEmpty else { return appModel.entities }
        return appModel.entities.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.entityID.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var grouped: [(domain: String, entities: [HomeAssistantEntity])] {
        Dictionary(grouping: filteredEntities, by: \.domain)
            .map { ($0.key, $0.value) }
            .sorted { EntityPresentation.title(for: $0.domain) < EntityPresentation.title(for: $1.domain) }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.domain) { group in
                Section(EntityPresentation.title(for: group.domain)) {
                    ForEach(group.entities) { entity in
                        NavigationLink {
                            EntityDetailView(entityID: entity.entityID, appModel: appModel)
                        } label: {
                            EntityRow(entity: entity)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Alle Entitäten")
        .searchable(text: $searchText, prompt: "Name oder Entity-ID")
        .overlay {
            if filteredEntities.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}
