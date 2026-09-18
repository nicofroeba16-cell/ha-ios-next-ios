import Foundation
import SwiftUI

struct EntityControlView: View {
    let entityID: String
    let appModel: AppModel

    private var entity: HomeAssistantEntity? {
        appModel.entities.first { $0.entityID == entityID }
    }

    var body: some View {
        Group {
            if let entity {
                List {
                    Section {
                        EntityRow(entity: entity)
                        if !entity.isAvailable {
                            Label("Diese Entität ist momentan nicht verfügbar.", systemImage: "wifi.slash")
                                .foregroundStyle(.orange)
                        }
                    }
                    control(for: entity)
                        .disabled(!entity.isAvailable)
                }
                .navigationTitle(entity.displayName)
            } else {
                EmptyFeatureView(
                    title: "Entität nicht verfügbar",
                    symbol: "exclamationmark.triangle",
                    message: "Die Entität ist nicht mehr im aktuellen Home-Assistant-Zustand vorhanden."
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    @ViewBuilder
    private func control(for entity: HomeAssistantEntity) -> some View {
        switch entity.controlKind {
        case .light:
            Section("Licht") {
                Button(entity.isOn ? "Ausschalten" : "Einschalten") {
                    Task { await appModel.toggle(entity) }
                }
                if let brightness = entity.brightness {
                    BrightnessControl(value: brightness / 255) { newValue in
                        Task { await appModel.setBrightness(newValue, for: entity) }
                    }
                }
            }
        case .toggle:
            Section("Steuerung") {
                Button(entity.isOn ? "Ausschalten" : "Einschalten") {
                    Task { await appModel.toggle(entity) }
                }
            }
        case .cover:
            Section("Abdeckung") {
                HStack {
                    Button("Öffnen") { Task { await appModel.callService(for: entity, service: "open_cover") } }
                    Spacer()
                    Button("Stop") { Task { await appModel.callService(for: entity, service: "stop_cover") } }
                    Spacer()
                    Button("Schließen") { Task { await appModel.callService(for: entity, service: "close_cover") } }
                }
            }
        case .climate:
            Section("Klima") {
                if let current = entity.currentTemperature {
                    LabeledContent("Aktuell", value: String(format: "%.1f °C", current))
                }
                if let target = entity.targetTemperature {
                    TemperatureControl(value: target) { newValue in
                        Task { await appModel.setTemperature(newValue, for: entity) }
                    }
                }
            }
        case .lock:
            Section("Schloss") {
                Button(entity.state == "locked" ? "Entsperren" : "Sperren") {
                    Task { await appModel.setLocked(entity.state != "locked", for: entity) }
                }
            }
        case .scene:
            Section("Szene") {
                Button("Aktivieren") { Task { await appModel.activate(entity) } }
            }
        case .script:
            Section("Script") {
                Button("Ausführen") { Task { await appModel.activateScript(entity) } }
            }
        case .media:
            Section("Medien") {
                Text("Weitere Mediensteuerung befindet sich im Tab Medien.")
                    .foregroundStyle(.secondary)
            }
        case .readOnly:
            Section("Status") {
                LabeledContent("Wert", value: entity.secondaryStateText)
            }
        }
    }
}
private struct BrightnessControl: View {
    @State private var value: Double
    let onCommit: (Double) -> Void

    init(value: Double, onCommit: @escaping (Double) -> Void) {
        _value = State(initialValue: value)
        self.onCommit = onCommit
    }

    var body: some View {
        HStack {
            Image(systemName: "sun.min")
            Slider(value: $value, in: 0 ... 1) { editing in
                if !editing { onCommit(value) }
            }
            Image(systemName: "sun.max.fill")
        }
        .accessibilityLabel("Helligkeit")
    }
}

private struct TemperatureControl: View {
    @State private var value: Double
    let onCommit: (Double) -> Void

    init(value: Double, onCommit: @escaping (Double) -> Void) {
        _value = State(initialValue: value)
        self.onCommit = onCommit
    }
    var body: some View {
        VStack(alignment: .leading) {
            LabeledContent("Solltemperatur", value: String(format: "%.1f °C", value))
            Slider(value: $value, in: 5 ... 35, step: 0.5) { editing in
                if !editing { onCommit(value) }
            }
        }
        .accessibilityLabel("Solltemperatur")
    }
}
