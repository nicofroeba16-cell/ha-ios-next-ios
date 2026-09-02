import SwiftUI

struct RoomsView: View {
    let appModel: AppModel

    private var roomNames: [String] {
        appModel.profileDefinition.roomNames
    }

    var body: some View {
        List(roomNames, id: \.self) { room in
            NavigationLink {
                RoomDetailView(title: room, appModel: appModel)
            } label: {
                Label(room, systemImage: roomIcon(for: room))
                    .font(.body.weight(.medium))
                    .frame(minHeight: 44)
            }
        }
        .navigationTitle("Räume")
    }

    private func roomIcon(for room: String) -> String {
        room == "Rasen" ? "leaf.fill" : "door.left.hand.open"
    }
}

private struct RoomDetailView: View {
    let title: String
    let appModel: AppModel

    var body: some View {
        List {
            Section("Geräte") {
                let devices = appModel.entities.filter { $0.entityID.hasPrefix("light.") || $0.entityID.hasPrefix("switch.") }
                if devices.isEmpty {
                    EmptyFeatureView(title: "Keine Geräte geladen", symbol: "square.grid.2x2", message: "Nach der Entitätszuordnung erscheinen hier die Geräte dieses Raums.")
                } else {
                    ForEach(devices.prefix(10)) { entity in
                        EntityRow(entity: entity) { Task { await appModel.toggle(entity) } }
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}
