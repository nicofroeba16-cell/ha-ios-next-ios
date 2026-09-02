import SwiftUI

struct ConnectionStatusLabel: View {
    let state: AppModel.ConnectionState

    var body: some View {
        Label(state.statusText, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityLabel("Home Assistant: \(state.statusText)")
    }

    private var icon: String {
        switch state {
        case .connected: "checkmark.circle.fill"
        case .connecting: "arrow.triangle.2.circlepath"
        case .notConfigured, .failed: "exclamationmark.circle.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .connected: .green
        case .connecting: .orange
        case .notConfigured, .failed: .red
        }
    }
}

struct EntityRow: View {
    let entity: HomeAssistantEntity
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(entity.isOn ? Color.accentColor : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.displayName)
                    .font(.body.weight(.medium))
                Text(entity.state.localizedCapitalized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let action {
                Button(action: action) {
                    Image(systemName: entity.isOn ? "power.circle.fill" : "power.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(entity.displayName) \(entity.isOn ? "ausschalten" : "einschalten")")
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var icon: String {
        if entity.entityID.hasPrefix("light.") { return "lightbulb.fill" }
        if entity.entityID.hasPrefix("media_player.") { return "play.rectangle.fill" }
        if entity.entityID.hasPrefix("scene.") { return "circle.hexagongrid.fill" }
        if entity.entityID.hasPrefix("switch.") { return "switch.2" }
        return "circle.grid.2x2.fill"
    }
}

struct EmptyFeatureView: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
            .padding(.vertical, 36)
    }
}
