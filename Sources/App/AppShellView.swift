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
        TabView(selection: $selectedTab) {
            tab(.home) { HomeView(appModel: appModel) }
            tab(.rooms) { RoomsView(appModel: appModel) }
            tab(.media) { MediaView(appModel: appModel) }
            tab(.scenes) { ScenesView(appModel: appModel) }
            tab(.system) { SystemView(appModel: appModel) }
        }
        .tint(.accentColor)
    }

    private func tab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
        }
        .tabItem { Label(tab.title, systemImage: tab.icon) }
        .tag(tab)
    }
}
