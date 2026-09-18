import SwiftUI

struct FeaturedAreaPresentation {
    let sourceName: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
}

struct HomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let appModel: AppModel

    private var nicoArea: HomeAssistantArea? { area(named: "Nico Zimmer") }
    private var featuredAreas: [FeaturedAreaPresentation] {
        [
            .init(sourceName: "Timo Zimmer", title: "Timo-Zimmer", subtitle: "Persönlicher Bereich", symbol: "house.lodge.fill", tint: .blue),
            .init(sourceName: "Hütte Master", title: "Hütte", subtitle: "Gartenhaus & Medien", symbol: "house.and.flag.fill", tint: .orange),
            .init(sourceName: "Pool", title: "Außenbereich", subtitle: "Pool & Garten", symbol: "tree.fill", tint: .green),
            .init(sourceName: "Wohnzimmer", title: "Wohnzimmer", subtitle: "TV & Medien", symbol: "sofa.fill", tint: .teal)
        ]
    }

    var body: some View {
        ZStack {
            IOS27HomeBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    OwnerHomeHeader(connectionState: appModel.connectionState)
                    if let nicoArea { heroCard(for: nicoArea) }

                    sectionTitle("Häufig genutzt")
                    LazyVGrid(columns: featuredColumns, spacing: 12) {
                        ForEach(Array(featuredAreas.enumerated()), id: \.offset) { _, item in
                            if let area = area(named: item.sourceName) {
                                NavigationLink {
                                    RoomDetailView(area: area, appModel: appModel)
                                } label: {
                                    roomCard(area: area, item: item)
                                }
                                .buttonStyle(IOS27PressStyle())
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(item.title)
                                .accessibilityValue("\(appModel.devices(inArea: area.id).count) Geräte, \(activeCount(in: area)) aktiv")
                                .accessibilityHint("Öffnet den Raum")
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                    }

                    sectionTitle("System & Geräte")
                    systemStrip
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Zuhause")
        .navigationBarTitleDisplayMode(.large)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 2)
            .accessibilityAddTraits(.isHeader)
    }

    private func heroCard(for area: HomeAssistantArea) -> some View {
        NavigationLink {
            RoomDetailView(area: area, appModel: appModel)
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.24))
                RadialGradient(
                    colors: [Color.purple.opacity(0.42), .clear],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: 260
                )
                LinearGradient(
                    colors: [Color.indigo.opacity(0.16), .clear],
                    startPoint: .topTrailing,
                    endPoint: .center
                )

                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        Image(systemName: "house.fill")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.10), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.7))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Nico-Zimmer")
                            .font(.title2.weight(.bold))
                        Text("Dein Bereich · Medien & Licht")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            heroStatusChips(for: area)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            heroStatusChips(for: area)
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(20)
            }
            .frame(maxWidth: .infinity, minHeight: 224, alignment: .leading)
            .ios27ContentSurface(radius: 30, elevated: true)
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(IOS27PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nico-Zimmer")
        .accessibilityValue("\(appModel.devices(inArea: area.id).count) Geräte, \(activeCount(in: area)) aktiv")
        .accessibilityHint("Öffnet den Raum")
        .accessibilityAddTraits(.isButton)
    }

    private func roomCard(area: HomeAssistantArea, item: FeaturedAreaPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.tint)
                    .frame(width: 38, height: 38)
                    .background(item.tint.opacity(0.12), in: Circle())
                    .overlay(Circle().stroke(item.tint.opacity(0.16), lineWidth: 0.7))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Text("\(appModel.devices(inArea: area.id).count) Geräte")
                Spacer(minLength: 4)
                Circle().fill(activeCount(in: area) > 0 ? item.tint : Color.secondary.opacity(0.4)).frame(width: 5, height: 5)
                Text("\(activeCount(in: area)) aktiv")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .ios27ContentSurface(radius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var systemStrip: some View {
        HStack(spacing: 0) {
            HomeMetricTile(title: "Räume", value: "\(appModel.areas.count)", icon: "square.grid.2x2.fill", tint: .blue)
            divider
            HomeMetricTile(title: "Geräte", value: "\(appModel.devices.count)", icon: "cpu.fill", tint: .indigo)
            divider
            HomeMetricTile(title: "Warnungen", value: "\(unavailableCount)", icon: "exclamationmark.triangle.fill", tint: unavailableCount > 0 ? .orange : .green)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .ios27ContentSurface(radius: 24)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 0.5, height: 44)
    }

    @ViewBuilder
    private func heroStatusChips(for area: HomeAssistantArea) -> some View {
        HomeStatusChip(text: "\(activeCount(in: area, domain: "light")) Licht", symbol: "lightbulb.fill")
        HomeStatusChip(text: "\(activeCount(in: area, domain: "media_player")) Medien", symbol: "play.tv.fill")
        HomeStatusChip(text: "\(appModel.devices(inArea: area.id).count) Geräte", symbol: "cpu")
    }

    private var featuredColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private func area(named name: String) -> HomeAssistantArea? {
        appModel.areas.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    private func activeCount(in area: HomeAssistantArea, domain: String? = nil) -> Int {
        appModel.entities(inArea: area.id).filter { entity in
            (domain == nil || entity.domain == domain) && entity.isOn
        }.count
    }

    private var unavailableCount: Int { appModel.entities.filter { !$0.isAvailable }.count }
}

#Preview("Dark Owner Home") {
    NavigationStack { HomeView(appModel: .preview) }
        .preferredColorScheme(.dark)
}
