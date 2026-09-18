import SwiftUI

struct IOS27HomeBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [Color.indigo.opacity(0.10), .clear, Color.purple.opacity(0.05)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            RadialGradient(
                colors: [Color.blue.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 330
            )
        }
        .ignoresSafeArea()
    }
}

struct IOS27Surface: ViewModifier {
    let radius: CGFloat
    let tint: Color
    let elevated: Bool

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(
                tint.opacity(0.055),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.16), .white.opacity(0.035), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: elevated ? tint.opacity(0.16) : .black.opacity(0.08), radius: elevated ? 24 : 12, y: elevated ? 12 : 6)
    }
}

extension View {
    func ios27Surface(radius: CGFloat = 24, tint: Color = .clear, elevated: Bool = false) -> some View {
        modifier(IOS27Surface(radius: radius, tint: tint, elevated: elevated))
    }
}

struct OwnerHomeHeader: View {
    let connectionState: AppModel.ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ZUHAUSE")
                .font(.caption2.weight(.bold))
                .tracking(1.15)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nico")
                        .font(.largeTitle.weight(.bold))
                    Text("Dein Zuhause")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HomeConnectionPill(state: connectionState)
            }
        }
        .padding(.top, 2)
    }
}

struct HomeConnectionPill: View {
    let state: AppModel.ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(state.statusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .ios27Surface(radius: 18, tint: tint)
        .accessibilityLabel("Home Assistant: \(state.statusText)")
    }

    private var tint: Color {
        switch state {
        case .connected: .green
        case .connecting, .reconnecting: .orange
        case .notConfigured, .failed: .red
        }
    }
}

struct HomeStatusChip: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.90))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.09), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.7))
    }
}

struct HomeMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .contentTransition(.numericText())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 86)
    }
}

struct IOS27PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
