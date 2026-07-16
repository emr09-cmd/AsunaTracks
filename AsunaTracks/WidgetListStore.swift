import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetListItem: Codable, Identifiable {
    let id: Int                 // AsunaTracks media ID
    let title: String
    let imageURL: String?
    var progress: Int
    let total: Int
    let mediaType: String
    let status: String
}

enum WidgetListStore {
    static let suiteName = "group.com.asunatracks.shared"
    private static let itemsKey = "upNextItems"
    private static let pendingKey = "widgetProgressIncrements"

    #if os(iOS)
    static func save(entries: [MyListEntry]) {
        let items = entries.filter { ["watching", "reading", "rewatching", "rereading"].contains($0.status ?? "") }.map { entry in
            WidgetListItem(id: entry.media.id, title: entry.media.title_english?.isEmpty == false ? entry.media.title_english! : entry.media.title, imageURL: entry.media.image_url, progress: entry.progress ?? 0, total: entry.media.media_type == "manga" ? (entry.media.chapters ?? 0) : (entry.media.episodes ?? 0), mediaType: entry.media.media_type ?? "anime", status: entry.status ?? "watching")
        }
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(try? JSONEncoder().encode(items), forKey: itemsKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    #endif

    static func pendingIncrements() -> [Int: Int] {
        let raw = UserDefaults(suiteName: suiteName)?.dictionary(forKey: pendingKey) ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
            guard let mediaID = Int(key), let count = value as? Int else { return nil }
            return (mediaID, count)
        })
    }

    static func clearPendingIncrement(for mediaID: Int) {
        let defaults = UserDefaults(suiteName: suiteName)
        var values = defaults?.dictionary(forKey: pendingKey) ?? [:]
        values.removeValue(forKey: String(mediaID))
        defaults?.set(values, forKey: pendingKey)
    }
}
