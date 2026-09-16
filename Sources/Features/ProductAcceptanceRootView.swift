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

struct ProductAcceptanceRootView: View {
    private let screen: ProductAcceptanceScreen
    @State private var appModel = AppModel.preview
    @State private var chatModel = ChatModel.preview

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        screen = Self.screen(from: arguments)
    }

    var body: some View {
        Group {
            if let tab = screen.initialTab {
                AppShellView(appModel: appModel, chatModel: chatModel, initialTab: tab)
            } else {
                standaloneScreen
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("product-acceptance-\(screen.rawValue)")
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
}
