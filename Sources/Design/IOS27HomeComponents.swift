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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let radius: CGFloat
    let tint: Color
    let elevated: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
        } else if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(tint),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .shadow(
                    color: elevated ? tint.opacity(0.12) : .clear,
                    radius: elevated ? 20 : 0,
                    y: elevated ? 10 : 0
                )
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
        }
    }
}

extension View {
    func ios27Surface(radius: CGFloat = 24, tint: Color = .clear, elevated: Bool = false) -> some View {
        modifier(IOS27Surface(radius: radius, tint: tint, elevated: elevated))
    }
}

struct IOS27ContentSurface: ViewModifier {
    let radius: CGFloat
    let elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(Color(.secondarySystemGroupedBackground), in: shape)
            .overlay(shape.stroke(Color.primary.opacity(0.055), lineWidth: 0.5))
            .shadow(color: elevated ? Color.black.opacity(0.10) : .clear, radius: elevated ? 14 : 0, y: elevated ? 7 : 0)
    }
}

extension View {
    func ios27ContentSurface(radius: CGFloat = 24, elevated: Bool = false) -> some View {
        modifier(IOS27ContentSurface(radius: radius, elevated: elevated))
    }
}

struct OwnerHomeHeader: View {
    let connectionState: AppModel.ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

// Adjacent glass controls share one rendering container. Add glassEffectID only when a control actually morphs between distinct glass views; static groups intentionally do not use IDs.
struct IOS27GlassControlGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

struct IOS27GlassButtonStyle: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

extension View {
    func ios27GlassButton(prominent: Bool = false) -> some View {
        modifier(IOS27GlassButtonStyle(prominent: prominent))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

private struct IOS27ScrollBottomClearance: ViewModifier {
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: 72)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func ios27ScrollBottomClearance() -> some View {
        modifier(IOS27ScrollBottomClearance())
    }
}
