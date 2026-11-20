import Foundation
import GRDB

extension ShoppingList {
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
