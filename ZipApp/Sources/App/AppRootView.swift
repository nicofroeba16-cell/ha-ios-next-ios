import SwiftUI

struct AppRootView: View {
    let appModel: AppModel

    var body: some View {
        Group {
            if appModel.isConnected {
                AppShellView(appModel: appModel)
            } else {
                ConnectionLandingView(appModel: appModel)
            }
        }
        .task { await appModel.restoreConnection() }
        .sheet(isPresented: Bindable(appModel).isPresentingConnection) {
            ConnectionSetupView(appModel: appModel)
        }
    }
}

private struct ConnectionLandingView: View {
    let appModel: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("iOS Next")
                    .font(.largeTitle.bold())
                Text("Deine native Home-Assistant-App")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if case let .failed(message) = appModel.connectionState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button("Home Assistant verbinden") {
                appModel.isPresentingConnection = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Öffnet die sichere Einrichtung der Home-Assistant-Verbindung.")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
