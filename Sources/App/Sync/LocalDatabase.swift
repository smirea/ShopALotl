import Foundation
import GRDB

final class LocalDatabase: Sendable {
    #if os(iOS)
    /// In the app group, so the widget reads and checks the same rows.
    static let url = AppGroup.container.appending(path: "shopalotl.sqlite")
    /// Where the app kept the database before it had a widget.
    static let legacyURL = URL.applicationSupportDirectory.appending(path: "shopalotl/shopalotl.sqlite")
    #else
    static let url = URL.applicationSupportDirectory.appending(path: "shopalotl/shopalotl.sqlite")
    #endif

    let pool: DatabasePool

    init(at url: URL = LocalDatabase.url) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var configuration = Configuration()
        // The app and the widget write the same file from two processes, and GRDB opens every write transaction as
        // IMMEDIATE, so the second writer waits for the first instead of failing with SQLITE_BUSY.
        configuration.busyMode = .timeout(5)
        pool = try DatabasePool(path: url.path, configuration: configuration)
    }

    /// Moves the database at `legacy`, with its WAL and shared-memory files, to `url`. A database already at `url`
    /// wins and the legacy one stays where it is, so a move never overwrites rows. Call it before either is open.
    static func adopt(_ legacy: URL, into url: URL) throws {
        let files = FileManager.default
        guard files.fileExists(atPath: legacy.path), !files.fileExists(atPath: url.path) else { return }
        try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // The main file goes last: once it exists at `url` the move counts as done, so a move cut short reruns.
        for suffix in ["-wal", "-shm", ""] {
            let from = URL(filePath: legacy.path + suffix)
            let to = URL(filePath: url.path + suffix)
            guard files.fileExists(atPath: from.path) else { continue }
            if files.fileExists(atPath: to.path) { try files.removeItem(at: to) }
            try files.moveItem(at: from, to: to)
        }
    }
}
