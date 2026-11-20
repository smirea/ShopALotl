import Foundation
import GRDB
import Testing
@testable import App

@Suite struct LocalDatabaseTests {
    private func folder() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func items(at url: URL) throws -> [String] {
        try DatabaseQueue(path: url.path).read { try String.fetchAll($0, sql: "SELECT name FROM items") }
    }

    private func write(_ name: String, at url: URL) throws {
        let database = try LocalDatabase(at: url)
        try database.pool.write { db in
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS items (name TEXT)")
            try db.execute(sql: "INSERT INTO items VALUES (?)", arguments: [name])
        }
    }

    @Test func anUpdatedInstallKeepsItsRowsWhenTheDatabaseMovesToTheSharedContainer() throws {
        let root = try folder()
        let legacy = root.appending(path: "app/shopalotl.sqlite")
        let shared = root.appending(path: "group/shopalotl.sqlite")
        try write("Milk", at: legacy)

        try LocalDatabase.adopt(legacy, into: shared)

        #expect(try items(at: shared) == ["Milk"])
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test func aDatabaseAlreadyInTheSharedContainerIsNeverOverwritten() throws {
        let root = try folder()
        let legacy = root.appending(path: "app/shopalotl.sqlite")
        let shared = root.appending(path: "group/shopalotl.sqlite")
        try write("Old", at: legacy)
        try write("New", at: shared)

        try LocalDatabase.adopt(legacy, into: shared)

        #expect(try items(at: shared) == ["New"])
        #expect(try items(at: legacy) == ["Old"])
    }
}
