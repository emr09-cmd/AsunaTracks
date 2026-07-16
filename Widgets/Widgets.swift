import WidgetKit
import SwiftUI
import AppIntents

struct UpNextItem: Codable, Identifiable {
    let id: Int; let title: String; let imageURL: String?; var progress: Int; let total: Int; let mediaType: String; let status: String
}

enum SharedWidgetStore {
    static let suite = "group.com.asunatracks.shared"
    static func items() -> [UpNextItem] {
        guard let data = UserDefaults(suiteName: suite)?.data(forKey: "upNextItems") else { return [] }
        return (try? JSONDecoder().decode([UpNextItem].self, from: data)) ?? []
    }
}

struct TrackedMediaEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tracked Title")
    static let defaultQuery = TrackedMediaQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct TrackedMediaQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TrackedMediaEntity] { available().filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [TrackedMediaEntity] { available() }
    private func available() -> [TrackedMediaEntity] { SharedWidgetStore.items().map { TrackedMediaEntity(id: String($0.id), name: $0.title) } }
}

struct UpNextConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Up Next Settings"
    static let description = IntentDescription("Choose which tracked title to show.")
    @Parameter(title: "Title") var title: TrackedMediaEntity?
    init() {}
}

struct UpNextEntry: TimelineEntry { let date: Date; let items: [UpNextItem] }

struct UpNextProvider: AppIntentTimelineProvider {
    typealias Intent = UpNextConfigurationIntent
    func placeholder(in context: Context) -> UpNextEntry { UpNextEntry(date: .now, items: []) }
    func snapshot(for configuration: UpNextConfigurationIntent, in context: Context) async -> UpNextEntry { makeEntry(configuration) }
    func timeline(for configuration: UpNextConfigurationIntent, in context: Context) async -> Timeline<UpNextEntry> { Timeline(entries: [makeEntry(configuration)], policy: .after(.now.addingTimeInterval(15 * 60))) }
    private func makeEntry(_ configuration: UpNextConfigurationIntent) -> UpNextEntry {
        let items = SharedWidgetStore.items()
        let selected = configuration.title.flatMap { id in items.first { String($0.id) == id.id } }
        return UpNextEntry(date: .now, items: selected.map { [$0] } ?? items)
    }
}

struct Poster: View {
    let item: UpNextItem
    var body: some View {
        Group {
            if let url = URL(string: item.imageURL ?? "") {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { ZStack { Color.secondary.opacity(0.18); Image(systemName: "film").foregroundStyle(.secondary) } }
                }
            } else { ZStack { Color.secondary.opacity(0.18); Image(systemName: "film").foregroundStyle(.secondary) } }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ProgressControls: View {
    let item: UpNextItem
    var body: some View {
        HStack(spacing: 8) {
            ProgressView(value: Double(item.progress), total: Double(max(item.total, 1))).tint(.pink)
            Button(intent: IncrementProgressIntent(mediaID: item.id)) { Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(.pink) }.buttonStyle(.plain)
        }
    }
}

struct UpNextWidgetView: View {
    let entry: UpNextEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if let item = entry.items.first {
            switch family {
            case .systemSmall: small(item)
            case .systemLarge: large(entry.items)
            default: medium(item)
            }
        } else { empty }
    }
    private func small(_ item: UpNextItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Poster(item: item).frame(maxWidth: .infinity).frame(height: 86)
            Text(item.title).font(.headline).lineLimit(1)
            ProgressControls(item: item)
            Text("\(item.progress)\(item.total > 0 ? "/\(item.total)" : "")").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func medium(_ item: UpNextItem) -> some View {
        HStack(spacing: 12) {
            Poster(item: item).frame(width: 74, height: 108)
            VStack(alignment: .leading, spacing: 9) {
                Text("UP NEXT").font(.caption2.weight(.bold)).foregroundStyle(.pink)
                Text(item.title).font(.headline).lineLimit(2)
                Text("\(item.mediaType.capitalized) • \(item.progress)\(item.total > 0 ? "/\(item.total)" : "")").font(.caption).foregroundStyle(.secondary)
                ProgressControls(item: item)
            }
        }
    }
    private func large(_ items: [UpNextItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UP NEXT").font(.caption.weight(.bold)).foregroundStyle(.pink)
            ForEach(items.prefix(3)) { item in HStack(spacing: 10) { Poster(item: item).frame(width: 42, height: 58); VStack(alignment: .leading) { Text(item.title).font(.subheadline.bold()).lineLimit(1); ProgressControls(item: item) } } }
            Spacer(minLength: 0)
        }
    }
    private var empty: some View { VStack(spacing: 8) { Image(systemName: "play.rectangle").font(.title2); Text("No active titles").font(.headline); Text("Track a title in AsunaTracks to see it here.").font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary) } }
}

struct UpNextWidget: Widget {
    let kind = "AsunaTracksUpNext"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: UpNextConfigurationIntent.self, provider: UpNextProvider()) { UpNextWidgetView(entry: $0).containerBackground(.fill.tertiary, for: .widget) }
            .configurationDisplayName("Up Next")
            .description("See and update a tracked title.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
