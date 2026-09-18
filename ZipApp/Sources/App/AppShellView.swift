import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case rooms
    case media
    case scenes
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Zuhause"
        case .rooms: "Räume"
        case .media: "Medien"
        case .scenes: "Szenen"
        case .system: "System"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .rooms: "square.grid.2x2.fill"
        case .media: "play.tv.fill"
        case .scenes: "circle.hexagongrid.fill"
        case .system: "gearshape.fill"
        }
    }
}

struct AppShellView: View {
    let appModel: AppModel
    @State private var selectedTab: AppTab = .home

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                TabView(selection: $selectedTab) {
                    Tab(AppTab.home.title, systemImage: AppTab.home.icon, value: .home) { tabNavigation { HomeView(appModel: appModel) } }
                    Tab(AppTab.rooms.title, systemImage: AppTab.rooms.icon, value: .rooms) { tabNavigation { RoomsView(appModel: appModel) } }
                    Tab(AppTab.media.title, systemImage: AppTab.media.icon, value: .media) { tabNavigation { MediaView(appModel: appModel) } }
                    Tab(AppTab.scenes.title, systemImage: AppTab.scenes.icon, value: .scenes) { tabNavigation { ScenesView(appModel: appModel) } }
                    Tab(AppTab.system.title, systemImage: AppTab.system.icon, value: .system) { tabNavigation { SystemView(appModel: appModel) } }
                }
            } else {
                TabView(selection: $selectedTab) {
                    legacyTab(.home) { HomeView(appModel: appModel) }
                    legacyTab(.rooms) { RoomsView(appModel: appModel) }
                    legacyTab(.media) { MediaView(appModel: appModel) }
                    legacyTab(.scenes) { ScenesView(appModel: appModel) }
                    legacyTab(.system) { SystemView(appModel: appModel) }
                }
            }
        }
        .tint(.accentColor)
    }

    private func tabNavigation<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack { content() }
    }

    private func legacyTab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        tabNavigation { content() }
            .tabItem { Label(tab.title, systemImage: tab.icon) }
            .tag(tab)
    }
}
