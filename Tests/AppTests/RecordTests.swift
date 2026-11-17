import Foundation
import GRDB
import Testing
@testable import App

@MainActor @Suite struct RecordTests {
    @Test func anInstantKeepsItsMillisecondHoweverOftenItIsReadAndWritten() throws {
        for millisecond in 0..<2000 {
            let text = Instant.text(Date(timeIntervalSince1970: 1_794_702_639 + Double(millisecond) / 1000))
            #expect(Instant.text(try #require(Instant.parse(text))) == text)
        }
        #expect(Instant.text(Date(timeIntervalSince1970: 1_794_702_639.0026)) == "2026-11-15T00:30:39.003Z")
    }

    @Test func anItemReadsBackAsWritten() throws {
        let store = try makeStore()
        let item = Item(
            id: ItemID(listID: "main", key: NameKey("Oat Milk")!), name: "Oat Milk", state: .checked, quantity: "2", note: "barista",
            addedAt: .at(0), bought: [.at(10), .at(20)]
        )
        store.write { try item.insert($0) }
        let read = try store.database.pool.read { try Item.readable($0, sql: "SELECT * FROM items") }
        #expect(read == [item])
    }

    @Test func aListKeepsItsAisleOrderAndAppendsTheRest() throws {
        let store = try makeStore()
        let list = ShoppingList(id: "costco", name: "Costco", grouping: .category, categoryOrder: [.frozen, .produce], position: 1, createdAt: .at(0))
        store.write { try list.insert($0) }
        let read = try store.database.pool.read { try ShoppingList.readable($0, sql: "SELECT * FROM lists") }
        #expect(read == [list])
    }

    @Test func aRowThisVersionCannotReadIsSkipped() throws {
        let store = try makeStore()
        store.write { db in
            try db.execute(sql: "INSERT INTO items (id, list_id, name, state, added_at) VALUES ('main/a', 'main', 'A', 'teleported', '2026-11-14T09:00:00.000Z')")
            try db.execute(sql: "INSERT INTO items (id, list_id, name, added_at) VALUES ('main/b', 'main', 'B', '2026-11-14T09:00:00.000Z')")
            try db.execute(sql: "INSERT INTO item_categories (id, name_key, source, category) VALUES ('b#user', 'b', 'user', 'hovercraft')")
        }
        let items = try store.database.pool.read { try Item.readable($0, sql: "SELECT * FROM items") }
        #expect(items.map(\.name) == ["B"])
        let answers = try store.database.pool.read { try CategoryAnswer.readable($0, sql: "SELECT * FROM item_categories") }
        #expect(answers.isEmpty)
    }
}
