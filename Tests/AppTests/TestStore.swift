import Foundation
@testable import App

/// A store over a fresh database file that never syncs.
@MainActor
func makeStore() throws -> LocalStore {
    let directory = FileManager.default.temporaryDirectory.appending(path: "shopalotl-tests-\(UUID().uuidString)")
    return try LocalStore(unsyncedAt: directory.appending(path: "test.sqlite"))
}

extension Date {
    /// Whole milliseconds, which is what a row keeps.
    static func at(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + seconds) }
}
