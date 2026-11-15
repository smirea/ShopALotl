import Foundation
import GRDB

extension ShoppingList {
    /// Every list in switcher order. The first list shows without a row until the owner changes it.
    static let all = DatabaseQuery([ShoppingList.main]) { db in try fetchAll(db) }

    static func fetchAll(_ db: Database) throws -> [ShoppingList] {
        let rows = try readable(db, sql: "SELECT * FROM lists ORDER BY position, created_at, id")
        return rows.contains { $0.id == main.id } ? rows : [main] + rows
    }

    static func fetch(_ db: Database, id: String) throws -> ShoppingList? {
        try readable(db, sql: "SELECT * FROM lists WHERE id = ?", arguments: [id]).first ?? (id == main.id ? main : nil)
    }
}

extension ListSnapshot {
    /// Nil when the list is gone, such as after another device deleted it.
    static func fetch(_ db: Database, listID: String) throws -> ListSnapshot? {
        guard let list = try ShoppingList.fetch(db, id: listID) else { return nil }
        var answers: [NameKey: CategoryAnswers] = [:]
        for answer in try CategoryAnswer.readable(db, sql: "SELECT * FROM item_categories") {
            switch answer.source {
            case .user: answers[answer.nameKey, default: .init()].user = answer.category
            case .model: answers[answer.nameKey, default: .init()].model = answer.category
            }
        }
        let items = try Item.readable(db, sql: "SELECT * FROM items WHERE list_id = ?", arguments: [listID])
        return ListSnapshot(list: list, items: items, answers: answers)
    }
}

extension LocalStore {
    @discardableResult
    func createList(named name: String, grouping: Grouping, at now: Date = .now) -> ShoppingList? {
        write { db in
            let last = try Double.fetchOne(db, sql: "SELECT MAX(position) FROM lists") ?? 0
            let list = ShoppingList(id: UUID().uuidString.lowercased(), name: name, grouping: grouping, categoryOrder: [], position: last + 1, createdAt: now)
            try list.insert(db)
            return list
        }
    }

    /// Changes a list, writing only the columns that differ. The first change to the first list creates its row.
    func updateList(_ id: String, at now: Date = .now, _ change: (inout ShoppingList) -> Void) {
        write { db in
            if let existing = try ShoppingList.fetchOne(db, key: id) {
                var changed = existing
                change(&changed)
                try changed.updateChanges(db, from: existing)
            } else if id == ShoppingList.main.id {
                var created = ShoppingList.main
                created.createdAt = now
                change(&created)
                try created.insert(db)
            }
        }
    }

    /// Deletes a list and everything it remembers. The first list always exists, so it is only emptied.
    func deleteList(_ id: String) {
        write { db in
            try db.execute(sql: "DELETE FROM items WHERE list_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM lists WHERE id = ?", arguments: [id])
        }
    }
}

extension ShoppingList {
    /// How many items each list still needs, for the list switcher.
    static let neededCounts = DatabaseQuery([String: Int]()) { db in
        let rows = try Row.fetchAll(db, sql: "SELECT list_id, COUNT(*) AS needed FROM items WHERE state = 'needed' GROUP BY list_id")
        return Dictionary(uniqueKeysWithValues: rows.map { ($0["list_id"] as String, $0["needed"] as Int) })
    }
}
