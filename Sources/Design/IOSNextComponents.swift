import SwiftUI

enum IOSNextLayout {
    static let pageSpacing: CGFloat = 24
    static let sectionSpacing: CGFloat = 14
    static let cardRadius: CGFloat = 24
    static let compactRadius: CGFloat = 18
    static let pageMaxWidth: CGFloat = 760
}

struct IOSNextBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color.accentColor.opacity(0.055),
                Color(uiColor: .systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct IOSNextPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            IOSNextBackground()
            ScrollView {
                content
                    .frame(maxWidth: IOSNextLayout.pageMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct IOSNextSectionHeader: View {
    let title: String
    var subtitle: String?
    var symbol: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ConnectionStatusLabel: View {
    let state: AppModel.ConnectionState

    var body: some View {
        Label(state.statusText, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.13), in: Capsule())
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

struct IOSNextMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Text(value)
                .font(.title2.weight(.bold))
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .iosNextCard()
        .accessibilityElement(children: .combine)
    }
}

struct EntityRow: View {
    let entity: HomeAssistantEntity
    var isWorking = false
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(iconTint.opacity(entity.isOn ? 0.17 : 0.09))
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(entity.isAvailable ? iconTint : .secondary)
            }
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(entity.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(entity.stateDisplayName)
                    .font(.footnote)
                    .foregroundStyle(entity.isAvailable ? .secondary : .red)
            }
            Spacer(minLength: 8)

            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Aktion läuft")
            } else if let action {
                Button(action: action) {
                    Image(systemName: entity.isOn ? "power.circle.fill" : "power.circle")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!entity.isAvailable)
                .accessibilityLabel("\(entity.displayName) \(entity.isOn ? "ausschalten" : "einschalten")")
            } else {
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: action == nil ? .combine : .contain)
    }

    private var icon: String {
        switch entity.domain {
        case "light": entity.isOn ? "lightbulb.fill" : "lightbulb"
        case "media_player": "play.rectangle.fill"
        case "scene": "sparkles"
        case "switch": "switch.2"
        case "climate": "thermometer.medium"
        case "cover": "window.shade.open"
        case "camera": "video.fill"
        case "lock": entity.isOn ? "lock.open.fill" : "lock.fill"
        case "binary_sensor": "sensor.fill"
        default: "circle.grid.2x2.fill"
        }
    }

    private var iconTint: Color {
        guard entity.isAvailable else { return .secondary }
        switch entity.domain {
        case "light": entity.isOn ? .yellow : .secondary
        case "media_player": .purple
        case "scene": .indigo
        case "climate": .orange
        case "cover": .blue
        case "camera", "lock": .red
        default: entity.isOn ? .accentColor : .secondary
        }
    }
}

struct EmptyFeatureView: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
            .frame(maxWidth: .infinity, minHeight: 180)
    }
}

struct IOSNextErrorBanner: View {
    let message: String
    var dismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let dismiss {
                Button("Schließen", systemImage: "xmark", action: dismiss)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fehlermeldung schließen")
            }
        }
        .padding(14)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct IOSNextCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(
                reduceTransparency ? AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)) : AnyShapeStyle(.regularMaterial),
                in: RoundedRectangle(cornerRadius: IOSNextLayout.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: IOSNextLayout.cardRadius, style: .continuous)
                    .strokeBorder(.white.opacity(reduceTransparency ? 0 : 0.12), lineWidth: 0.5)
            }
    }
}

extension View {
    func iosNextCard() -> some View {
        modifier(IOSNextCardModifier())
    }
}
