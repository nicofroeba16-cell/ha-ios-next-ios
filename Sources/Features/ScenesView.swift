import SwiftUI

struct ScenesView: View {
    let appModel: AppModel

    private var scenes: [HomeAssistantEntity] {
        appModel.entities(inDomain: "scene")
    }

    var body: some View {
        IOSNextPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.pageSpacing) {
                IOSNextSectionHeader(
                    title: "Szenen",
                    subtitle: "Mehrere Geräte mit einer Aktion einstellen",
                    symbol: "sparkles"
                )

                if scenes.isEmpty {
                    EmptyFeatureView(
                        title: "Keine Szenen geladen",
                        symbol: "sparkles",
                        message: "Home-Assistant-Szenen werden nach der Verbindung hier angezeigt."
                    )
                    .iosNextCard()
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach(scenes) { scene in
                            Button {
                                Task { await appModel.activate(scene) }
                            } label: {
                                VStack(alignment: .leading, spacing: 18) {
                                    Image(systemName: "sparkles")
                                        .font(.title2.weight(.semibold))
                                        .foregroundStyle(.indigo)
                                    Spacer(minLength: 0)
                                    Text(scene.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(2)
                                    Text("Aktivieren")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                                .padding(18)
                                .iosNextCard()
                            }
                            .buttonStyle(.plain)
                            .disabled(appModel.activeActionEntityIDs.contains(scene.entityID))
                            .accessibilityHint("Aktiviert diese Home-Assistant-Szene")
                        }
                    }
                }
            }
        }
        .navigationTitle("Szenen")
    }
}
