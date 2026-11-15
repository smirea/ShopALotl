import Foundation
import GRDB
import Testing
@testable import App

@MainActor @Suite struct ItemActionsTests {
    private let store: LocalStore
    private let list = ShoppingList.main.id

    init() throws {
        store = try makeStore()
    }

    private func id(_ name: String) -> ItemID { ItemID(listID: list, key: NameKey(name)!) }

    private func items() throws -> [String] {
        try store.database.pool.read { try Item.readable($0, sql: "SELECT * FROM items ORDER BY id") }
            .map { "\($0.name) \($0.state.rawValue)\($0.quantity.isEmpty ? "" : " ×\($0.quantity)") bought:\($0.bought.count)" }
    }

    private func add(_ text: String, at seconds: TimeInterval = 0) -> ItemChange {
        store.add(EntryParser.entries(in: text), to: list, at: .at(seconds))
    }

    @Test func addingPutsNewItemsOnTheListAndUpdatesTheAmountOfOnesAlreadyThere() throws {
        _ = add("milk, 2 eggs")
        _ = add("3 milk")
        #expect(try items() == ["Eggs needed ×2 bought:0", "Milk needed ×3 bought:0"])
    }

    @Test func aCheckRecordsAPurchaseAndAQuickUncheckTakesItBack() throws {
        _ = add("milk")
        store.toggleChecked(id("milk"), at: .at(100))
        #expect(try items() == ["Milk checked bought:1"])
        store.toggleChecked(id("milk"), at: .at(200))
        #expect(try items() == ["Milk needed bought:0"])
    }

    @Test func anUncheckLongAfterTheCheckKeepsThePurchase() throws {
        _ = add("milk")
        store.toggleChecked(id("milk"), at: .at(0))
        store.toggleChecked(id("milk"), at: .at(7 * 3600))
        #expect(try items() == ["Milk needed bought:1"])
    }

    @Test func clearingRemembersWhatWasBoughtAndReaddingBringsItBackWithItsAmount() throws {
        _ = add("2 milk, eggs")
        store.toggleChecked(id("milk"), at: .at(10))
        let cleared = store.clearChecked(in: list)
        #expect(cleared.rows.map(\.id) == [id("milk")])
        #expect(try items() == ["Eggs needed bought:0", "Milk off ×2 bought:1"])
        _ = add("milk", at: 500)
        #expect(try items() == ["Eggs needed bought:0", "Milk needed ×2 bought:1"])
    }

    @Test func removingAnItemNeverBoughtLeavesNothingAndOneBoughtBeforeIsRemembered() throws {
        _ = add("mlik, milk")
        store.toggleChecked(id("milk"), at: .at(0))
        store.toggleChecked(id("milk"), at: .at(7 * 3600))
        store.remove(id("mlik"))
        store.remove(id("milk"))
        #expect(try items() == ["Milk off bought:1"])
    }

    @Test func undoPutsBackExactlyWhatAGestureChanged() throws {
        _ = add("milk, eggs, bread")
        store.toggleChecked(id("milk"), at: .at(1))
        store.toggleChecked(id("eggs"), at: .at(2))
        let before = try items()
        let cleared = store.clearChecked(in: list)
        store.undo(cleared)
        #expect(try items() == before)
        let removed = store.remove(id("bread"))
        #expect(try items().count == 2)
        store.undo(removed)
        #expect(try items() == before)
    }

    @Test func undoLeavesARowAloneOnceSomethingElseChangedIt() throws {
        _ = add("milk")
        store.toggleChecked(id("milk"), at: .at(1))
        let cleared = store.clearChecked(in: list)
        _ = add("milk", at: 50)
        store.undo(cleared)
        store.undo(cleared)
        #expect(try items() == ["Milk needed bought:1"])
    }

    @Test func renamingMovesTheItemToItsNewKeyWithItsPurchases() throws {
        _ = add("milk")
        store.toggleChecked(id("milk"), at: .at(0))
        store.toggleChecked(id("milk"), at: .at(7 * 3600))
        let moved = store.edit(id("milk"), name: "Oat milk", quantity: "2")
        #expect(moved.rows.map(\.id) == [id("milk"), id("oat milk")])
        #expect(try items() == ["Oat milk needed ×2 bought:1"])
        #expect(store.edit(id("oat milk"), name: "  ").isEmpty)
        #expect(try items() == ["Oat milk needed ×2 bought:1"])
    }

    @Test func anEditWritesOnlyTheFieldsItNamesSoAnotherDevicesEditOfTheRestSurvives() throws {
        _ = add("2 milk")
        try store.database.pool.write { try $0.execute(sql: "DELETE FROM _outbox") }
        store.edit(id("milk"), note: "lactose free")
        let columns = try store.database.pool.read { try String.fetchAll($0, sql: "SELECT col FROM _outbox ORDER BY col") }
        #expect(columns == ["note"])
        #expect(try items() == ["Milk needed ×2 bought:0"])
    }

    @Test func undoOfAnAddThatNamedAnItemTwiceLeavesNothing() throws {
        let added = store.add(EntryParser.entries(in: "milk, 2 milk"), to: list, at: Date(timeIntervalSince1970: 1_794_702_639.0026))
        #expect(try items() == ["Milk needed ×2 bought:0"])
        store.undo(added)
        store.undo(added)
        #expect(try items() == [])
    }

    @Test func undoOfARenameOntoARememberedItemPutsBothRowsBack() throws {
        _ = add("3 milk, mlik")
        store.toggleChecked(id("milk"), at: .at(1))
        store.clearChecked(in: list)
        let before = try items()
        let renamed = store.edit(id("mlik"), name: "milk")
        #expect(try items() == ["milk needed bought:1"])
        store.undo(renamed)
        #expect(try items() == before)
    }

    @Test func aCheckSyncsAsOnePatchOfTheTwoColumnsItChanged() throws {
        _ = add("milk")
        try store.database.pool.write { try $0.execute(sql: "DELETE FROM _outbox") }
        store.toggleChecked(id("milk"), at: .at(1))
        let columns = try store.database.pool.read { try String.fetchAll($0, sql: "SELECT col FROM _outbox WHERE op != 'put' ORDER BY col") }
        #expect(columns == ["bought", "state"])
    }

    @Test func theOwnersCategoryAndTheModelsAreSeparateRows() throws {
        let key = NameKey("tahini")!
        store.setCategory(.dairy, for: key, source: .model)
        store.setCategory(.pantry, for: key)
        store.setCategory(.deli, for: key)
        let snapshot = try store.database.pool.read { try ListSnapshot.fetch($0, listID: list) }
        #expect(snapshot?.answers[key] == CategoryAnswers(user: .deli, model: .dairy))
    }

    @Test func theFirstListExistsWithoutARowAndGetsOneWhenChanged() throws {
        #expect(try store.database.pool.read(ShoppingList.fetchAll).map(\.name) == ["Groceries"])
        #expect(try store.database.pool.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM lists") } == 0)
        store.updateList(list) { $0.name = "Weekly shop" }
        let costco = try #require(store.createList(named: "Costco", grouping: .none))
        #expect(try store.database.pool.read(ShoppingList.fetchAll).map(\.name) == ["Weekly shop", "Costco"])
        store.add(EntryParser.entries(in: "tent"), to: costco.id)
        store.deleteList(costco.id)
        #expect(try store.database.pool.read(ShoppingList.fetchAll).map(\.name) == ["Weekly shop"])
        #expect(try items() == [])
    }
}
