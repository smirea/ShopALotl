import Foundation
import notify
import os
import SyncEngine

/// The widget's side of the shared database: what to draw, and a check that syncs at once.
@MainActor
final class WidgetStore {
    static let shared = WidgetStore()
    private static let syncedAtKey = "widgetSyncedAt"
    /// A timeline older than this pulls from the server before it draws, so another device's change shows up.
    private static let staleAfter: TimeInterval = 15 * 60

    private let log = Logger(subsystem: "com.stefan.shopalotl", category: "widget")
    private var opened: (database: LocalDatabase, client: SyncClient)?

    /// Nil until the app has created the database: the widget never creates it, or the app would find an empty one
    /// in the group and leave its own rows behind.
    private func open() -> (database: LocalDatabase, client: SyncClient)? {
        if let opened { return opened }
        guard FileManager.default.fileExists(atPath: LocalDatabase.url.path) else { return nil }
        do {
            let database = try LocalDatabase()
            let client = SyncClient(
                database: database.pool, schema: syncSchema, endpoint: AppEnvironment.apiURL.appending(path: "api"),
                token: { AppEnvironment.ownerToken }
            )
            try client.migrate()
            opened = (database, client)
            return opened
        } catch {
            log.error("Could not open the shared database: \(String(describing: error))")
            return nil
        }
    }

    /// The open list's rows in the app's order, without its aisle headers.
    func entry(at date: Date = .now) -> ListEntry {
        guard let database = open()?.database else { return ListEntry(date: date, rows: []) }
        let listID = AppGroup.defaults.string(forKey: AppGroup.Key.currentList) ?? ShoppingList.main.id
        let hidesChecked = AppGroup.defaults.bool(forKey: AppGroup.Key.hidesChecked)
        do {
            let snapshot = try database.pool.read { db in
                try ListSnapshot.fetch(db, listID: listID) ?? ListSnapshot.fetch(db, listID: ShoppingList.main.id)
            }
            guard let snapshot else { return ListEntry(date: date, rows: []) }
            let rows = Layout.sections(snapshot, hidingChecked: hidesChecked).flatMap(\.rows).map(\.item)
            return ListEntry(date: date, rows: rows)
        } catch {
            log.error("Could not read the list: \(String(describing: error))")
            return ListEntry(date: date, rows: [])
        }
    }

    /// Writes before the widget redraws, and sends the change without waiting for it: the server answers after the
    /// row has already changed on screen. A send the system cuts short stays in the outbox for the app's next sync.
    func setChecked(_ id: ItemID, _ checked: Bool) {
        guard let (database, client) = open() else { return }
        do {
            try database.pool.write { db in
                guard let item = try Item.fetchOne(db, key: id.text), item.isOnList, (item.state == .checked) != checked else { return }
                _ = try ItemWrites.toggle(db, id, at: .now)
            }
        } catch {
            log.error("Could not check \(id): \(String(describing: error))")
            return
        }
        notify_post(AppGroup.changedNotification)
        AppGroup.defaults.set(Date.now, forKey: Self.syncedAtKey)
        Task { await client.sync() }
    }

    /// Pulls from the server when the widget has not synced for a while, giving up after a few seconds offline.
    func syncIfStale() async {
        let last = AppGroup.defaults.object(forKey: Self.syncedAtKey) as? Date ?? .distantPast
        guard Date.now.timeIntervalSince(last) > Self.staleAfter, let client = open()?.client else { return }
        AppGroup.defaults.set(Date.now, forKey: Self.syncedAtKey)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await client.sync() }
            group.addTask { try? await Task.sleep(for: .seconds(5)) }
            await group.next()
            group.cancelAll()
        }
    }
}
