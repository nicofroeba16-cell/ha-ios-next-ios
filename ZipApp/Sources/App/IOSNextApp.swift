import SwiftUI

@main
struct IOSNextApp: App {
    @State private var appModel: AppModel

    init() {
        if ProcessInfo.processInfo.arguments.contains("--video-demo") {
            _appModel = State(initialValue: .preview)
        } else {
            _appModel = State(initialValue: AppModel())
        }
    }

    var body: some Scene {
        WindowGroup { AppRootView(appModel: appModel) }
    }
}
