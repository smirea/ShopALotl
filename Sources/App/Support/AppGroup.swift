import Foundation

/// What the app and its widget share: the database file, the open list, and whether checked rows show.
enum AppGroup {
    static let id = "group.com.stefan.shopalotl"
    static let widgetKind = "List"
    /// Posted by the widget after it writes, so a running app re-reads rows its observations cannot see change.
    static let changedNotification = "com.stefan.shopalotl.changed"

    enum Key {
        static let currentList = "currentList"
        static let hidesChecked = "hidesChecked"
    }

    #if os(iOS)
    static let container: URL = {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else {
            fatalError("No app group container for \(id). Check the target's entitlements.")
        }
        return url
    }()

    nonisolated(unsafe) static let defaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: id) else { fatalError("No user defaults for \(id).") }
        return defaults
    }()

    /// Settings saved before the widget lived in the app's own defaults. Copies each one that the group lacks.
    static func adoptStandardDefaults() {
        for key in [Key.currentList, Key.hidesChecked] where defaults.object(forKey: key) == nil {
            if let value = UserDefaults.standard.object(forKey: key) { defaults.set(value, forKey: key) }
        }
    }
    #else
    /// The Mac app has no widget, so it keeps its settings in its own defaults.
    static var defaults: UserDefaults { .standard }
    static func adoptStandardDefaults() {}
    #endif
}
