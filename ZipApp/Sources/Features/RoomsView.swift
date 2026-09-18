import SwiftUI

struct RoomsView: View {
    let appModel: AppModel

    var body: some View {
        List {
            if appModel.areas.isEmpty {
                EmptyFeatureView(
                    title: "Keine Räume geladen",
                    symbol: "door.left.hand.open",
                    message: "Home-Assistant-Areas erscheinen hier nach der Verbindung."
                )
            } else {
                ForEach(appModel.areas.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { area in
                    NavigationLink {
                        RoomDetailView(area: area, appModel: appModel)
                    } label: {
                        Label(area.name, systemImage: "door.left.hand.open")
                            .font(.body.weight(.medium))
                            .frame(minHeight: 44)
                    }
                }
            }
        }
        .navigationTitle("Räume")
    }
}

private struct RoomDetailView: View {
    let area: HomeAssistantArea
    let appModel: AppModel

    var body: some View {
        List {
            Section("Geräte") {
                let entities = appModel.entities(inArea: area.id)
                if entities.isEmpty {
                    EmptyFeatureView(
                        title: "Keine Geräte geladen",
                        symbol: "square.grid.2x2",
                        message: "Dieser Home-Assistant-Area sind aktuell keine Entitäten zugeordnet."
                    )
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
        .navigationTitle(area.name)
    }
}
