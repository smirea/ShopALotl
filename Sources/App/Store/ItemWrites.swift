import Foundation
import GRDB

/// What a gesture changed, row by row, kept so it can be taken back.
struct ItemChange: Equatable, Sendable {
    struct Row: Equatable, Sendable {
        let id: ItemID
        let before: Item?
        let after: Item?
    }

    var rows: [Row] = []
    var isEmpty: Bool { rows.isEmpty }
}

/// Item writes over a database connection, shared by the app's verbs and the widget's check.
enum ItemWrites {
    static func toggle(_ db: Database, _ id: ItemID, at now: Date) throws -> ItemChange {
        var change = ItemChange()
        try apply(db, id, to: &change) { $0.map { Edits.toggled($0, at: now) } }
        return change
    }

    /// Writes the row `transform` makes of the current one, as the smallest write: an insert, a delete, or an update
    /// of the columns that differ, which syncs as one patch. The change records the row as the database now reads
    /// it, because a row keeps whole milliseconds and undo compares against what it reads later.
    static func apply(_ db: Database, _ id: ItemID, to change: inout ItemChange, _ transform: (Item?) -> Item?) throws {
        let before = try Item.fetchOne(db, key: id.text)
        let after = transform(before)
        guard before != after else { return }
        switch (before, after) {
        case let (before?, after?): try after.updateChanges(db, from: before)
        case let (nil, after?): try after.insert(db)
        case let (before?, nil): try before.delete(db)
        case (nil, nil): break
        }
        change.rows.append(.init(id: id, before: before, after: try Item.fetchOne(db, key: id.text)))
    }
}
