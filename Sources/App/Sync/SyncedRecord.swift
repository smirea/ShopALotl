import Foundation
import GRDB

/// A row of one synced table, read and written through GRDB. The id column is the record's `key`.
protocol SyncedRecord: FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable where ID: Sendable {
    static var table: String { get }
    var key: String { get }
}

extension SyncedRecord {
    static var databaseTableName: String { table }
}

struct RowDecodingError: Error, CustomStringConvertible {
    let description: String
}

/// Timestamps on the wire and in SQLite: ISO 8601 in UTC with milliseconds, which sorts as text.
enum Instant {
    private static let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// Rounds to the millisecond. The format style cuts the fraction off instead, and a parsed instant sits a hair
    /// under its millisecond, so without the rounding a row lost a millisecond each time it was read and written.
    static func text(_ date: Date) -> String {
        let milliseconds = (date.timeIntervalSince1970 * 1000).rounded()
        return Date(timeIntervalSince1970: (milliseconds + 0.5) / 1000).formatted(style)
    }

    static func parse(_ text: String) -> Date? { try? style.parse(text) }
}

extension Row {
    func instant(_ column: String) throws -> Date {
        let text: String = self[column]
        guard let date = Instant.parse(text) else { throw RowDecodingError(description: "\(column) is not an instant: \(text)") }
        return date
    }

    /// A JSON array column. An element another app version wrote and this one cannot read is dropped, so one bad
    /// element never hides the row.
    func array<Element>(_ column: String, _ element: (String) -> Element?) throws -> [Element] {
        let text: String = self[column]
        guard let values = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [Any] else {
            throw RowDecodingError(description: "\(column) is not a JSON array: \(text)")
        }
        return values.compactMap { ($0 as? String).flatMap(element) }
    }
}

enum RowJSON {
    /// The same strings always encode to the same text, so re-saving an unchanged array fires no update trigger.
    static func text(_ strings: [String]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: strings, options: [.withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }
}
