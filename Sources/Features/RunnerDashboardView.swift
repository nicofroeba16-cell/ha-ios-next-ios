import SwiftUI

struct RunnerDashboardView: View {
    @State private var model = RunnerControlModel()
    @State private var pendingAction: RunnerAction?

    var body: some View {
        Group {
            switch model.state {
            case .notConfigured:
                ContentUnavailableView {
                    Label("Runner nicht eingerichtet", systemImage: "server.rack")
                } description: {
                    Text("Verbinde die App mit dem begrenzten Runner-Control-Dienst. SSH- und GitHub-Zugangsdaten bleiben außerhalb der App.")
                } actions: {
                    Button("Einrichten") { model.isPresentingConfiguration = true }
                        .buttonStyle(.glassProminent)
                }
            case .loading:
                ProgressView("Runner wird geladen …")
            case let .failed(message):
                ContentUnavailableView {
                    Label("Runner nicht erreichbar", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(message)
                } actions: {
                    Button("Erneut versuchen") { Task { await model.refresh() } }
                        .buttonStyle(.glassProminent)
                    Button("Konfiguration öffnen") { model.isPresentingConfiguration = true }
                        .buttonStyle(.glass)
                }
            case let .ready(status):
                dashboard(status)
            }
        }
        .navigationTitle("Runner")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Runner-Aktion fehlgeschlagen", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK") { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "Unbekannter Fehler")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Konfigurieren", systemImage: "gearshape") {
                    model.isPresentingConfiguration = true
                }
                .labelStyle(.iconOnly)
            }
        }
        .task {
            await model.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await model.refresh()
            }
        }
        .refreshable { await model.refresh() }
        .sheet(isPresented: $model.isPresentingConfiguration) {
            RunnerConfigurationView(model: model)
        }
        .confirmationDialog(
            pendingAction?.title ?? "Runner-Aktion",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingAction {
                Button(action.title, role: action == .shutdown ? .destructive : nil) {
                    Task { await model.perform(action) }
                    pendingAction = nil
                }
            }
            Button("Abbrechen", role: .cancel) { pendingAction = nil }
        } message: {
            Text("Laufende Jobs werden geschützt. Kritische Aktionen verlangen zusätzlich die Geräteauthentifizierung.")
        }
    }

    private func dashboard(_ status: RunnerStatus) -> some View {
        IOSNextPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.pageSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(status.serviceActive ? "Runner bereit" : "Runner gestoppt")
                            .font(.largeTitle.bold())
                        Text(status.vmOnline ? "Ubuntu-VM erreichbar" : "Ubuntu-VM offline")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: status.serviceActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(status.serviceActive ? .green : .red)
                        .accessibilityHidden(true)
                }
                .padding(20)
                .iosNextCard()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    IOSNextMetricCard(title: "Registriert", value: "\(status.registeredRunners)", symbol: "server.rack")
                    IOSNextMetricCard(title: "Frei", value: "\(status.idleRunners)", symbol: "checkmark.circle.fill", tint: .green)
                    IOSNextMetricCard(title: "Beschäftigt", value: "\(status.busyRunners)", symbol: "hammer.fill", tint: .orange)
                    if let disk = status.diskPercent {
                        IOSNextMetricCard(title: "Speicher", value: "\(Int(disk)) %", symbol: "internaldrive.fill", tint: disk > 85 ? .red : .blue)
                    }
                }

                IOSNextSectionHeader(title: "Steuerung", subtitle: "Nur fest freigegebene Aktionen", symbol: "switch.2")
                VStack(spacing: 12) {
                    actionButton(.healthCheck, symbol: "stethoscope")
                    actionButton(.pause, symbol: "pause.circle.fill")
                    actionButton(.resume, symbol: "play.circle.fill")
                    actionButton(.gracefulRestart, symbol: "arrow.triangle.2.circlepath")
                    actionButton(.shutdown, symbol: "power", destructive: true)
                }
            }
        }
    }

    private func actionButton(_ action: RunnerAction, symbol: String, destructive: Bool = false) -> some View {
        Button {
            pendingAction = action
        } label: {
            HStack {
                Label(action.title, systemImage: symbol)
                Spacer()
                if action.requiresBiometrics {
                    Image(systemName: "faceid")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Geräteauthentifizierung erforderlich")
                }
            }
            .foregroundStyle(destructive ? Color.red : Color.primary)
            .padding(16)
            .iosNextCard()
        }
        .buttonStyle(.plain)
    }
}

private struct RunnerConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let model: RunnerControlModel
    @State private var endpoint = ""
    @State private var token = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Runner-Control-Dienst") {
                    TextField("https://runner-control.local/", text: $endpoint)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Zugriffstoken", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Die App unterstützt keine freie Shell. Der Dienst darf ausschließlich die fest definierten Status- und Steuerendpunkte bereitstellen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button("Konfiguration entfernen", role: .destructive) {
                        model.removeConfiguration()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Runner einrichten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        do {
                            try model.configure(endpoint: endpoint, token: token)
                            Task { await model.refresh() }
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(endpoint.isEmpty || token.isEmpty)
                }
            }
        }
    }
}
