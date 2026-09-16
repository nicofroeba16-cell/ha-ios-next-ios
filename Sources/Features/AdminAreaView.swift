import Foundation
import SwiftUI

struct AdminAreaView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = AdminControlModel()
    @State private var isPresentingConfiguration = false
    @State private var pendingAction: AdminAction?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Owner Control")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") {
                            model.lock()
                            dismiss()
                        }
                    }
                    if case .unlocked = model.state {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Sperren", systemImage: "lock.fill") { model.lock() }
                                .labelStyle(.iconOnly)
                        }
                    }
                }
        }
        .interactiveDismissDisabled(model.state == .unlocking)
        .alert("Admin-Aktion fehlgeschlagen", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK") { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "Unbekannter Fehler")
        }
        .sheet(isPresented: $isPresentingConfiguration) {
            AdminConfigurationView(model: model)
        }
        .confirmationDialog(
            pendingAction?.title ?? "Admin-Aktion",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingAction {
                Button(action.title, role: action == .clearCache ? .destructive : nil) {
                    Task { await model.perform(action) }
                    pendingAction = nil
                }
            }
            Button("Abbrechen", role: .cancel) { pendingAction = nil }
        } message: {
            Text("Das Backend protokolliert diese Aktion. Veränderungen erfordern eine erneute Face-ID-Bestätigung.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .notConfigured:
            ContentUnavailableView {
                Label("Owner-Zugang nicht eingerichtet", systemImage: "person.badge.key.fill")
            } description: {
                Text("Die Einrichtung erfordert die HTTPS-Adresse des Admin-Backends und ein serverseitiges Owner-Token.")
            } actions: {
                Button("Owner-Zugang einrichten") { isPresentingConfiguration = true }
                    .buttonStyle(.glassProminent)
            }
        case .locked:
            unlockView(message: "Der Bereich ist lokal gesperrt.")
        case .unlocking:
            ProgressView("Owner-Berechtigung wird geprüft …")
        case .unlocked:
            dashboard
        case let .failed(message):
            unlockView(message: message)
        }
    }

    private func unlockView(message: String) -> some View {
        ZStack {
            IOSNextBackground()
            VStack(spacing: 22) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Owner-Bereich")
                    .font(.largeTitle.bold())
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Mit Face ID entsperren", systemImage: "faceid") {
                    Task { await model.unlock() }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                Button("Konfiguration ändern") { isPresentingConfiguration = true }
                    .buttonStyle(.glass)
            }
            .padding(24)
        }
    }

    private var dashboard: some View {
        IOSNextPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.pageSpacing) {
                identityCard
                if let status = model.backendStatus {
                    statusSection(status)
                    actionsSection(status)
                } else {
                    ProgressView("Backend-Status wird geladen …")
                        .frame(maxWidth: .infinity, minHeight: 180)
                }
                auditSection
            }
        }
        .refreshable { await model.refresh() }
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.green.opacity(0.14))
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                if case let .unlocked(identity) = model.state {
                    Text(identity.displayName).font(.headline)
                    Text("Serverseitig als Owner bestätigt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "faceid").foregroundStyle(.secondary)
        }
        .padding(18)
        .iosNextCard()
    }

    private func statusSection(_ status: AdminBackendStatus) -> some View {
        VStack(alignment: .leading, spacing: IOSNextLayout.sectionSpacing) {
            IOSNextSectionHeader(
                title: "Backend",
                subtitle: "Version \(status.version) · \(status.environment)",
                symbol: "server.rack"
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                IOSNextMetricCard(
                    title: "Systemstatus",
                    value: status.healthy ? "Online" : "Gestört",
                    symbol: status.healthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    tint: status.healthy ? .green : .red
                )
                IOSNextMetricCard(
                    title: "WebSockets",
                    value: "\(status.activeWebSocketSessions)",
                    symbol: "network",
                    tint: .blue
                )
                IOSNextMetricCard(
                    title: "Warteschlange",
                    value: "\(status.queueDepth)",
                    symbol: "list.bullet.rectangle",
                    tint: status.queueDepth > 20 ? .orange : .green
                )
                IOSNextMetricCard(
                    title: "Cache",
                    value: "\(status.cacheEntries)",
                    symbol: "memorychip.fill",
                    tint: .purple
                )
                IOSNextMetricCard(
                    title: "Chat im RAM",
                    value: ByteCountFormatter.string(
                        fromByteCount: Int64(status.chatQueuedBytes ?? 0),
                        countStyle: .memory
                    ),
                    symbol: "message.badge.waveform.fill",
                    tint: (status.chatQueuedChunks ?? 0) > 0 ? .blue : .green
                )
            }
            if status.maintenanceMode {
                Label("Wartungsmodus aktiv", systemImage: "wrench.and.screwdriver.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func actionsSection(_ status: AdminBackendStatus) -> some View {
        VStack(alignment: .leading, spacing: IOSNextLayout.sectionSpacing) {
            IOSNextSectionHeader(
                title: "Wartung",
                subtitle: "Keine freie Shell · jede Aktion wird auditiert",
                symbol: "wrench.and.screwdriver.fill"
            )
            VStack(spacing: 0) {
                ForEach(availableActions(for: status)) { action in
                    Button {
                        pendingAction = action
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: action.symbol)
                                .frame(width: 28)
                                .foregroundStyle(action == .enableMaintenance ? Color.orange : Color.accentColor)
                            Text(action.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if action.requiresFreshBiometrics {
                                Image(systemName: "faceid").foregroundStyle(.secondary)
                            }
                        }
                        .frame(minHeight: 54)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isLoading)
                    if action.id != availableActions(for: status).last?.id {
                        Divider().padding(.leading, 42)
                    }
                }
            }
            .padding(.horizontal, 16)
            .iosNextCard()
        }
    }

    private var auditSection: some View {
        VStack(alignment: .leading, spacing: IOSNextLayout.sectionSpacing) {
            IOSNextSectionHeader(
                title: "Audit-Log",
                subtitle: "Die letzten serverseitig protokollierten Aktionen",
                symbol: "list.bullet.clipboard.fill"
            )
            if model.auditEvents.isEmpty {
                Text("Noch keine Audit-Ereignisse geladen.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .iosNextCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(model.auditEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.action).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(event.result)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(event.result == "success" ? .green : .orange)
                            }
                            Text(event.timestamp, format: .dateTime.day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                        if event.id != model.auditEvents.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .iosNextCard()
            }
        }
    }

    private func availableActions(for status: AdminBackendStatus) -> [AdminAction] {
        [
            .healthCheck,
            status.maintenanceMode ? .disableMaintenance : .enableMaintenance,
            .reconnectSessions,
            .clearCache,
            .rotateLogs,
            .createBackup
        ]
    }
}

private struct AdminConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let model: AdminControlModel
    @State private var endpoint = ""
    @State private var ownerToken = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Owner-Backend") {
                    TextField("https://admin.example.com/", text: $endpoint)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Owner-Token", text: $ownerToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Das Token wird ausschließlich im iOS-Schlüsselbund gespeichert. Der Server muss für `/v1/admin/session` die Rolle `owner` bestätigen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button("Owner-Konfiguration entfernen", role: .destructive) {
                        model.removeConfiguration()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Owner einrichten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        do {
                            try model.configure(endpoint: endpoint, ownerToken: ownerToken)
                            dismiss()
                            Task { await model.unlock() }
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(endpoint.isEmpty || ownerToken.isEmpty)
                }
            }
        }
    }
}
