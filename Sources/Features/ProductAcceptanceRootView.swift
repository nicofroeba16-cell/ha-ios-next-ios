import Foundation
import SwiftUI

enum ProductAcceptanceScreen: String, CaseIterable {
    case home
    case rooms
    case chat
    case media
    case system
    case light
    case mediaDetail = "media-detail"
    case owner
    case wireguard

    var initialTab: AppTab? {
        switch self {
        case .home: .home
        case .rooms: .rooms
        case .chat: .chat
        case .media: .media
        case .system: .system
        case .light, .mediaDetail, .owner, .wireguard: nil
        }
    }
}

private struct ProductAcceptanceOptions {
    let colorScheme: ColorScheme?
    init(arguments: [String]) {
        colorScheme = arguments.contains("--product-ui-test-dark") ? .dark : .light
    }
}

struct ProductAcceptanceRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var screen: ProductAcceptanceScreen
    @State private var forcedColorScheme: ColorScheme?
    @State private var appModel = AppModel.preview
    @State private var chatModel = ChatModel.preview

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let initialScreen = Self.screen(from: arguments)
        let options = ProductAcceptanceOptions(arguments: arguments)
        _screen = State(initialValue: initialScreen)
        _forcedColorScheme = State(initialValue: options.colorScheme)
    }

    var body: some View {
        Group {
            if let tab = screen.initialTab {
                AppShellView(appModel: appModel, chatModel: chatModel, initialTab: tab)
            } else {
                standaloneScreen
            }
        }
        .id("product-acceptance-view-\(screen.rawValue)-\(appearanceName)")
        .preferredColorScheme(forcedColorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("product-acceptance-\(screen.rawValue)")
        .overlay(alignment: .topLeading) {
            VStack(spacing: 0) {
                accessibilityProbe
                routeReadyProbe
            }
        }
        .onOpenURL { url in
            guard let route = Self.route(from: url) else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                screen = route.screen
                forcedColorScheme = route.colorScheme
            }
        }
    }

    private var appearanceName: String {
        forcedColorScheme == .dark ? "dark" : "light"
    }

    private var routeReadyProbe: some View {
        Text("Product acceptance ready")
            .font(.system(size: 1))
            .foregroundStyle(.clear)
            .frame(width: 1, height: 1)
            .accessibilityIdentifier("product-acceptance-ready-\(screen.rawValue)-\(appearanceName)")
    }

    private var accessibilityStateSummary: String {
        [
            "dynamicTypeAccessibility=\(dynamicTypeSize.isAccessibilitySize)",
            "reduceMotion=\(reduceMotion)",
            "reduceTransparency=\(reduceTransparency)",
            "increasedContrast=\(colorSchemeContrast == .increased)"
        ].joined(separator: ";")
    }

    private var accessibilityProbe: some View {
        Text("Accessibility state")
            .font(.system(size: 1))
            .foregroundStyle(.clear)
            .frame(width: 1, height: 1)
            .accessibilityIdentifier("accessibility-state-probe")
            .accessibilityValue(accessibilityStateSummary)
    }

    @ViewBuilder
    private var standaloneScreen: some View {
        switch screen {
        case .light:
            NavigationStack {
                EntityDetailView(entityID: "light.hintergrund_fernseher", appModel: appModel)
            }
        case .mediaDetail:
            NavigationStack {
                EntityDetailView(entityID: "media_player.schlafzimmer", appModel: appModel)
            }
        case .owner:
            AdminAreaView()
        case .wireguard:
            NavigationStack {
                WireGuardView()
            }
        case .home, .rooms, .chat, .media, .system:
            EmptyView()
        }
    }

    static func screen(from arguments: [String]) -> ProductAcceptanceScreen {
        guard let argument = arguments.first(where: { $0.hasPrefix("--product-ui-test-screen=") }),
              let rawValue = argument.split(separator: "=").last.map(String.init),
              let screen = ProductAcceptanceScreen(rawValue: rawValue)
        else { return .home }
        return screen
    }

    static func route(from url: URL) -> (screen: ProductAcceptanceScreen, colorScheme: ColorScheme)? {
        guard url.scheme == "iosnext",
              url.host == "ci-product",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rawScreen = components.queryItems?.first(where: { $0.name == "screen" })?.value,
              let screen = ProductAcceptanceScreen(rawValue: rawScreen),
              let rawStyle = components.queryItems?.first(where: { $0.name == "style" })?.value
        else { return nil }

        switch rawStyle {
        case "light":
            return (screen, .light)
        case "dark":
            return (screen, .dark)
        default:
            return nil
        }
    }
}
