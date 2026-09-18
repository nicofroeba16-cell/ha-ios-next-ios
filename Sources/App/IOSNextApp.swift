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
                .modifier(QARenderingEnvironment())
        }
    }
}

private struct QARenderingEnvironment: ViewModifier {
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    private let arguments = ProcessInfo.processInfo.arguments

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(preferredColorScheme)
            .environment(\.dynamicTypeSize, arguments.contains("--qa-accessibility-text") ? .accessibility3 : systemDynamicTypeSize)
    }

    private var preferredColorScheme: ColorScheme? {
        if arguments.contains("--qa-light") { return .light }
        if arguments.contains("--qa-dark") || arguments.contains("--video-demo") { return .dark }
        return nil
    }
}
