import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case rooms
    case chat
    case media
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Zuhause"
        case .rooms: "Räume"
        case .chat: "Chat"
        case .media: "Medien"
        case .system: "Mehr"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .rooms: "square.grid.2x2.fill"
        case .chat: "message.fill"
        case .media: "play.tv.fill"
        case .system: "ellipsis.circle.fill"
        }
    }
}
struct AppShellView: View {
    let appModel: AppModel
    let chatModel: ChatModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppTab?

    init(appModel: AppModel, chatModel: ChatModel, initialTab: AppTab = .home) {
        self.appModel = appModel
        self.chatModel = chatModel
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                tabletShell
            } else {
                phoneShell
            }
        }
        .tint(.accentColor)
        .alert("Aktion fehlgeschlagen", isPresented: errorBinding) {
            Button("OK") { appModel.dismissActionError() }
        } message: {
            Text(appModel.lastActionError ?? "Unbekannter Fehler")
        }
    }

    private var phoneShell: some View {
        TabView(selection: selectedTabBinding) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    content(for: tab)
                }
                .tabItem { Label(tab.title, systemImage: tab.icon) }
                .tag(tab)
                .accessibilityIdentifier("app-tab-\(tab.rawValue)")
            }
        }
    }

    private var tabletShell: some View {
        NavigationSplitView {
            List(AppTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
                    .accessibilityIdentifier("app-tab-\(tab.rawValue)")
            }
            .navigationTitle("iOS Next")
        } detail: {
            NavigationStack {
                content(for: selectedTab ?? .home)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(appModel: appModel)
        case .rooms: RoomsView(appModel: appModel)
        case .chat: ChatView(chatModel: chatModel)
        case .media: MediaView(appModel: appModel)
        case .system: SystemView(appModel: appModel)
        }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab ?? .home },
            set: { selectedTab = $0 }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appModel.lastActionError != nil },
            set: { if !$0 { appModel.dismissActionError() } }
        )
    }
}
