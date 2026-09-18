import SwiftUI

@main
struct IOSNextApp: App {
    @State private var appModel: AppModel

    init() {
        if ProcessInfo.processInfo.arguments.contains("--video-demo") {
            _appModel = State(initialValue: AppModel.preview)
        } else {
            _appModel = State(initialValue: AppModel())
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(appModel: appModel)
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--video-demo") ? .dark : nil)
        }
    }
}
