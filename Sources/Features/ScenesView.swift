import SwiftUI

struct ScenesView: View {
    let appModel: AppModel

    var body: some View {
        List {
            Section("Szenen") {
                let scenes = appModel.entities(inDomain: "scene")
                if scenes.isEmpty {
                    EmptyFeatureView(title: "Keine Szenen geladen", symbol: "circle.hexagongrid", message: "Home-Assistant-Szenen werden nach der Verbindung hier angezeigt.")
                } else {
                    ForEach(scenes) { scene in
                        Button {
                            Task { await appModel.activate(scene) }
                        } label: {
                            EntityRow(entity: scene)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Szenen")
    }
}
