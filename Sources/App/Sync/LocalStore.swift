import Foundation
import GRDB
import Observation
import os
import SyncEngine
#if os(iOS)
import notify
import WidgetKit
#endif

/// The app's one database and its sync client. Screens read it through `@Observe` and write through `write`.
@MainActor @Observable
final class LocalStore {
    nonisolated static let log = Logger(subsystem: "com.stefan.shopalotl", category: "store")

    @ObservationIgnored let database: LocalDatabase
    @ObservationIgnored private let client: SyncClient
    @ObservationIgnored private var widgetWatch: AnyDatabaseCancellable?
    @ObservationIgnored private var widgetReload: Task<Void, Never>?

    init() {
        do {
            #if os(iOS)
            try LocalDatabase.adopt(LocalDatabase.legacyURL, into: LocalDatabase.url)
            #endif
            database = try LocalDatabase()
            client = SyncClient(
                database: database.pool, schema: syncSchema, endpoint: AppEnvironment.apiURL.appending(path: "api"),
                token: { AppEnvironment.ownerToken }
            )
            try client.migrate()
        } catch {
            fatalError("Could not open the local database at \(LocalDatabase.url.path): \(error)")
        }
        client.start()
        #if os(iOS)
        watchForWidget()
        #endif
    }

    /// A store over a fresh file at `url` that migrates but never syncs, for tests.
    init(unsyncedAt url: URL) throws {
        database = try LocalDatabase(at: url)
        client = SyncClient(database: database.pool, schema: syncSchema, endpoint: URL(string: "http://localhost")!, token: { nil })
        try client.migrate()
    }

    /// Runs `body` in one transaction and returns once it is committed, so the screen never shows a state the
    /// database does not hold. The engine's triggers queue the change for the next sync.
    @discardableResult
    func write<T>(_ body: (Database) throws -> T) -> T? {
        do {
            return try database.pool.write(body)
        } catch {
            Self.log.error("A write failed: \(String(describing: error))")
            assertionFailure("A write failed: \(error)")
            return nil
        }
    }

    /// Re-reads every observed query. Observations see only this process's writes, so this picks up the widget's.
    func refreshFromOtherProcesses() {
        write { try $0.notifyChanges(in: .fullDatabase) }
    }

    #if os(iOS)
    /// Redraws the widget a moment after a change to the rows it shows, once for a burst of writes.
    func reloadWidget() {
        widgetReload?.cancel()
        widgetReload = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
        }
    }

    private func watchForWidget() {
        widgetWatch = DatabaseRegionObservation(tracking: Table("lists"), Table("items"), Table("item_categories"))
            .start(in: database.pool) { error in
                Self.log.error("Watching rows for the widget failed: \(String(describing: error))")
            } onChange: { [weak self] _ in
                Task { @MainActor in self?.reloadWidget() }
            }
        var token: Int32 = 0
        notify_register_dispatch(AppGroup.changedNotification, &token, .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFromOtherProcesses() }
        }
    }
    #endif

    var syncStatus: SyncStatus { client.status }
    /// Local changes the server has not confirmed.
    var unsyncedChanges: Int { client.pending }
    var lastSyncedAt: Date? { client.lastSyncAt }
    var cursor: Int { client.head }
    var rejected: [SyncRejection] { client.rejected }
}
