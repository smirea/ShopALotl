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

/// Sections as text, one "<section>: <names>" per section.
func drawn(_ sections: [ListSection]) -> [String] {
    sections.map { section in
        let title = switch section.id {
        case let .aisle(category): category.rawValue
        case .plain: "plain"
        case .checked: "checked"
        }
        return "\(title): \(section.rows.map(\.item.name).joined(separator: ", "))"
    }
}
