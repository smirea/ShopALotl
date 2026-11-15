import Foundation
import GRDB
import Observation
import os
import SyncEngine

/// The app's one database and its sync client. Screens read it through `@Observe` and write through `write`.
@MainActor @Observable
final class LocalStore {
    nonisolated static let log = Logger(subsystem: "com.stefan.shopalotl", category: "store")

    @ObservationIgnored let database: LocalDatabase
    @ObservationIgnored private let client: SyncClient

    init() {
        do {
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
    }

    /// A store over a fresh file at `url` that migrates but never syncs, for tests.
    init(unsyncedAt url: URL) throws {
        database = try LocalDatabase(at: url)
        client = SyncClient(database: database.pool, schema: syncSchema, endpoint: URL(string: "http://localhost")!, token: { nil })
        try client.migrate()
    }

    /// Runs `body` in one transaction and returns once it is committed, so the screen never shows a state the
    /// database does not hold. `GestureTimingTests` keeps a gesture's write and redraw inside a frame. The engine's
    /// triggers queue the change for the next sync.
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

    var syncStatus: SyncStatus { client.status }
    /// Local changes the server has not confirmed.
    var unsyncedChanges: Int { client.pending }
    var lastSyncedAt: Date? { client.lastSyncAt }
    var cursor: Int { client.head }
    var rejected: [SyncRejection] { client.rejected }
}

extension SyncedRecord {
    /// The rows of a query, without those this app version cannot read: one bad row never hides the rest.
    static func readable(_ db: Database, sql: String, arguments: StatementArguments = []) throws -> [Self] {
        try Row.fetchAll(db, sql: sql, arguments: arguments).compactMap { row in
            do {
                return try Self(row: row)
            } catch {
                LocalStore.log.error("Skipped a row of \(table): \(String(describing: error))")
                return nil
            }
        }
    }
}
