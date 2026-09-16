import SwiftUI

struct AppRootView: View {
    let appModel: AppModel
    @State private var chatModel = ChatModel()
    @State private var isPresentingStandaloneChat = false

    var body: some View {
        Group {
            if isAnimationAcceptanceMode {
                AnimationAcceptanceView()
            } else if isLiveCardTestMode {
                LiveHACardTestModeView()
            } else {
                switch appModel.connectionState {
            case .connected:
                AppShellView(appModel: appModel, chatModel: chatModel)
                    .transition(.opacity)
            case .connecting where !appModel.entities.isEmpty:
                AppShellView(appModel: appModel, chatModel: chatModel)
                    .overlay(alignment: .top) {
                        reconnectBanner
                    }
            default:
                ConnectionLandingView(appModel: appModel) {
                    isPresentingStandaloneChat = true
                }
                    .transition(.opacity)
                }
            }
        }
        .animation(IOSNextMotion.navigation, value: appModel.isConnected)
        .task {
            if !isLiveCardTestMode && !isAnimationAcceptanceMode {
                await appModel.restoreConnection()
            }
        }
        .sheet(isPresented: Bindable(appModel).isPresentingConnection) {
            ConnectionSetupView(appModel: appModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isPresentingStandaloneChat) {
            StandaloneChatView(chatModel: chatModel)
        }
    }

    private var isLiveCardTestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--live-card-test-mode")
    }

    private var isAnimationAcceptanceMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--animation-acceptance-mode")
    }

    private var reconnectBanner: some View {
        Label("Verbindung wird wiederhergestellt …", systemImage: "arrow.triangle.2.circlepath")
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 8)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
private struct ConnectionLandingView: View {
    let appModel: AppModel
    let openChat: () -> Void

    var body: some View {
        ZStack {
            IOSNextBackground()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.tint.opacity(0.14))
                    Image(systemName: "house.lodge.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(.tint)
                }
                .frame(width: 108, height: 108)
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("iOS Next")
                        .font(.largeTitle.bold())
                    Text("Dein Zuhause. Nativ auf iPhone und iPad.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if case let .failed(message) = appModel.connectionState {
                    IOSNextErrorBanner(message: message)
                        .frame(maxWidth: 520)
                }

                Spacer()
                Button("Home Assistant verbinden", systemImage: "link") {
                    appModel.isPresentingConnection = true
                }
                .font(.headline)
                .controlSize(.large)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .accessibilityHint("Öffnet die sichere Einrichtung der Home-Assistant-Verbindung.")
                Button("Verschlüsselten Chat öffnen", systemImage: "message.badge.shield.fill", action: openChat)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct StandaloneChatView: View {
    let chatModel: ChatModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ChatView(chatModel: chatModel)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Schließen", systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly)
                    }
                }
        }
    }
}
