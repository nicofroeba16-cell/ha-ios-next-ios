import SwiftUI

struct HomeView: View {
    let appModel: AppModel

    private var nicoArea: HomeAssistantArea? { area(named: "Nico Zimmer") }
    private var featuredAreas: [(String, String, String, Color)] {
        [
            ("Timo Zimmer", "Timo-Zimmer", "house.lodge.fill", .blue),
            ("Hütte Master", "Hütte", "house.and.flag.fill", .orange),
            ("Pool", "Außenbereich", "tree.fill", .green),
            ("Wohnzimmer", "Wohnzimmer", "sofa.fill", .teal)
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ownerHeader
                if let nicoArea { heroCard(for: nicoArea) }

                Text("Häufig genutzt")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 2)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(featuredAreas.enumerated()), id: \.offset) { _, item in
                        if let area = area(named: item.0) {
                            NavigationLink {
                                RoomDetailView(area: area, appModel: appModel)
                            } label: {
                                roomCard(area: area, title: item.1, icon: item.2, tint: item.3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(item.1)
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                }

                Text("System & Geräte")
                    .font(.title3.weight(.bold))
                    .padding(.top, 4)

                HStack(spacing: 10) {
                    metricCard(title: "Räume", value: "\(appModel.areas.count)", icon: "square.grid.2x2.fill")
                    metricCard(title: "Geräte", value: "\(appModel.devices.count)", icon: "cpu.fill")
                    metricCard(title: "Warnungen", value: "\(unavailableCount)", icon: "exclamationmark.triangle.fill")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Zuhause")
        .background(Color(.systemGroupedBackground))
    }

    private var ownerHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nico")
                    .font(.largeTitle.bold())
                Text("Owner · Admin & Zuhause")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ConnectionStatusLabel(state: appModel.connectionState)
        }
        .padding(.top, 4)
    }

    private func heroCard(for area: HomeAssistantArea) -> some View {
        NavigationLink {
            RoomDetailView(area: area, appModel: appModel)
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "house.fill")
                        .font(.title2)
                        .padding(12)
                        .background(.white.opacity(0.16), in: Circle())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                }
                Text("Nico-Zimmer")
                    .font(.title2.bold())
                Text("Dein Bereich · Medien & Licht")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                HStack(spacing: 14) {
                    statusPill("\(activeCount(in: area, domain: "light")) Licht", "lightbulb.fill")
                    statusPill("\(activeCount(in: area, domain: "media_player")) Medien", "play.tv.fill")
                    statusPill("\(appModel.devices(inArea: area.id).count) Geräte", "cpu.fill")
                }
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.purple.opacity(0.95), .indigo.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .shadow(color: .purple.opacity(0.22), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Nico-Zimmer")
    }

    private func roomCard(area: HomeAssistantArea, title: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: Circle())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text("\(appModel.devices(inArea: area.id).count) Geräte · \(activeCount(in: area)) aktiv")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.08)))
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.headline).foregroundStyle(.tint)
            Text(value).font(.title3.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statusPill(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.white.opacity(0.13), in: Capsule())
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
