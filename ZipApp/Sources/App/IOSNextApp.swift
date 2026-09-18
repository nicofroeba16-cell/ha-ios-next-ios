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
    @Environment(\.colorSchemeContrast) private var systemColorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private let arguments = ProcessInfo.processInfo.arguments

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(preferredColorScheme)
            .environment(\.dynamicTypeSize, arguments.contains("--qa-accessibility-text") ? .accessibility3 : systemDynamicTypeSize)
            .environment(\.colorSchemeContrast, arguments.contains("--qa-increased-contrast") ? .increased : systemColorSchemeContrast)
            .environment(\.accessibilityReduceTransparency, arguments.contains("--qa-reduce-transparency") || systemReduceTransparency)
            .environment(\.accessibilityReduceMotion, arguments.contains("--qa-reduce-motion") || systemReduceMotion)
    }

    private var preferredColorScheme: ColorScheme? {
        if arguments.contains("--qa-light") { return .light }
        if arguments.contains("--qa-dark") || arguments.contains("--video-demo") { return .dark }
        return nil
    }
}
