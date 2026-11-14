import Foundation
import GRDB

final class LocalDatabase: Sendable {
    static let url = URL.applicationSupportDirectory.appending(path: "shopalotl/shopalotl.sqlite")

    let pool: DatabasePool

    init(at url: URL = LocalDatabase.url) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        pool = try DatabasePool(path: url.path)
    }
}
