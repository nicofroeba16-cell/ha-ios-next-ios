import SwiftUI

struct ScenesView: View {
    let appModel: AppModel

    var body: some View {
        List {
            actionSection(
                title: "Szenen",
                entities: appModel.entities(inDomain: "scene"),
                emptyTitle: "Keine Szenen geladen",
                symbol: "circle.hexagongrid"
            ) { entity in
                await appModel.activate(entity)
            }
            actionSection(
                title: "Scripts",
                entities: appModel.entities(inDomain: "script"),
                emptyTitle: "Keine Scripts geladen",
                symbol: "scroll"
            ) { entity in
                await appModel.activateScript(entity)
            }
        }
        .navigationTitle("Szenen")
    }

    @ViewBuilder
    private func actionSection(
        title: String,
        entities: [HomeAssistantEntity],
        emptyTitle: String,
        symbol: String,
        action: @escaping (HomeAssistantEntity) async -> Void
    ) -> some View {
        Section(title) {
            if entities.isEmpty {
                EmptyFeatureView(
                    title: emptyTitle,
                    symbol: symbol,
                    message: "Home-Assistant-\(title) werden nach der Verbindung hier angezeigt."
                )
            } else {
                ForEach(entities) { entity in
                    Button {
                        Task { await action(entity) }
                    } label: {
                        EntityRow(entity: entity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
