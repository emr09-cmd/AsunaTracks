import AppIntents
import WidgetKit

struct IncrementProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Progress"
    static var description = IntentDescription("Marks the next episode or chapter as complete.")
    @Parameter(title: "Media ID") var mediaID: Int
    init() {}
    init(mediaID: Int) { self.mediaID = mediaID }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.asunatracks.shared")
        let key = "widgetProgressIncrements"
        var pending = defaults?.dictionary(forKey: key) ?? [:]
        pending[String(mediaID)] = (pending[String(mediaID)] as? Int ?? 0) + 1
        defaults?.set(pending, forKey: key)
        if let data = defaults?.data(forKey: "upNextItems"), var items = try? JSONDecoder().decode([UpNextItem].self, from: data), let index = items.firstIndex(where: { $0.id == mediaID }) {
            let maximum = items[index].total
            if maximum == 0 || items[index].progress < maximum { items[index].progress += 1 }
            defaults?.set(try? JSONEncoder().encode(items), forKey: "upNextItems")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
