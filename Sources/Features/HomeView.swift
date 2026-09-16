import SwiftUI

struct HomeView: View {
    let appModel: AppModel
    private let metricColumns = [GridItem(.adaptive(minimum: 145), spacing: 12)]

    var body: some View {
        IOSNextPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.pageSpacing) {
                header
                metrics
                favorites
                attentionSection
            }
        }
        .navigationTitle("Zuhause")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Profil", selection: Bindable(appModel).selectedProfile) {
                        ForEach(HomeProfile.allCases) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }
                } label: {
                    Label(appModel.selectedProfile.title, systemImage: "person.crop.circle")
                }
                .accessibilityLabel("Profil: \(appModel.selectedProfile.title)")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Aktualisieren", systemImage: "arrow.clockwise") {
                    Task { await appModel.refresh() }
                }
                .labelStyle(.iconOnly)
                .disabled(appModel.connectionState == .connecting)
            }
        }
        .refreshable { await appModel.refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(greeting)
                        .font(.largeTitle.bold())
                    Text(appModel.selectedProfile.primaryArea)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)
                ConnectionStatusLabel(state: appModel.connectionState)
            }
            Text(appModel.selectedProfile.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .iosNextCard()
    }

    private var metrics: some View {
        LazyVGrid(columns: metricColumns, spacing: 12) {
            IOSNextMetricCard(
                title: "Lichter aktiv",
                value: String(activeCount(in: "light")),
                symbol: "lightbulb.fill",
                tint: .yellow
            )
            IOSNextMetricCard(
                title: "Medien aktiv",
                value: String(activeCount(in: "media_player")),
                symbol: "play.tv.fill",
                tint: .purple
            )
            IOSNextMetricCard(
                title: "Nicht erreichbar",
                value: String(appModel.entities.filter { !$0.isAvailable }.count),
                symbol: "wifi.slash",
                tint: appModel.entities.contains { !$0.isAvailable } ? .red : .green
            )
        }
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: IOSNextLayout.sectionSpacing) {
            IOSNextSectionHeader(
                title: "Favoriten",
                subtitle: "Schneller Zugriff für \(appModel.selectedProfile.title)",
                symbol: "star.fill"
            )
            VStack(spacing: 0) {
                if appModel.profileFavorites.isEmpty {
                    EmptyFeatureView(
                        title: "Noch keine Favoriten",
                        symbol: "star",
                        message: "Für dieses Profil sind noch keine bestätigten Geräte hinterlegt."
                    )
                } else {
                    ForEach(appModel.profileFavorites) { entity in
                        EntityRow(
                            entity: entity,
                            isWorking: appModel.activeActionEntityIDs.contains(entity.entityID)
                        ) {
                            Task { await appModel.toggle(entity) }
                        }
                        if entity.id != appModel.profileFavorites.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .iosNextCard()
        }
    }

    @ViewBuilder
    private var attentionSection: some View {
        let unavailable = appModel.entities.filter { !$0.isAvailable }
        if !unavailable.isEmpty {
            VStack(alignment: .leading, spacing: IOSNextLayout.sectionSpacing) {
                IOSNextSectionHeader(
                    title: "Aufmerksamkeit erforderlich",
                    subtitle: "Diese Geräte melden keinen aktuellen Zustand.",
                    symbol: "exclamationmark.triangle.fill"
                )
                VStack(spacing: 0) {
                    ForEach(Array(unavailable.prefix(8))) { entity in
                        EntityRow(entity: entity)
                        if entity.id != unavailable.prefix(8).last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .iosNextCard()
            }
        }
    }

    private func activeCount(in domain: String) -> Int {
        appModel.entities(inDomain: domain).filter(\.isOn).count
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: "Guten Morgen, \(appModel.selectedProfile.title)"
        case 11..<17: "Hallo, \(appModel.selectedProfile.title)"
        case 17..<23: "Guten Abend, \(appModel.selectedProfile.title)"
        default: "Willkommen zu Hause"
        }
    }
}

#Preview("Verbunden") {
    NavigationStack { HomeView(appModel: .preview) }
}
