import Foundation
import Testing
@testable import App

@MainActor @Suite struct ListModelTests {
    private let store: LocalStore
    private let list = ShoppingList.main.id

    init() throws {
        store = try makeStore()
    }

    private func id(_ name: String) -> ItemID { ItemID(listID: list, key: NameKey(name)!) }

    @Test func aCheckedRowStaysInItsAisleAndOnlyTheRowsAGestureWroteMove() throws {
        let model = try #require(ListModel(listID: list, store: store))
        model.add("milk, bread, eggs")
        #expect(drawn(model.sections) == ["bakery: Bread", "dairy: Eggs, Milk"])

        model.toggle(id("milk"))
        model.remove(id("bread"))
        model.add("bananas")
        model.edit(id("eggs"), quantity: "12")
        #expect(drawn(model.sections) == ["produce: Bananas", "dairy: Eggs, Milk"])

        model.setCategory(.pantry, of: id("eggs"))
        #expect(drawn(model.sections) == ["produce: Bananas", "dairy: Milk", "pantry: Eggs"])
    }

    @Test func aRenameCanBeTakenBackAndAnAmountEditOffersNothing() throws {
        let model = try #require(ListModel(listID: list, store: store))
        model.add("mlik")
        model.edit(id("mlik"), quantity: "2")
        #expect(model.undoable == nil)

        model.edit(id("mlik"), name: "Milk")
        #expect(model.undoable != nil)
        #expect(drawn(model.sections) == ["dairy: Milk"])
        model.undo()
        #expect(model.snapshot.items.map(\.name) == ["Mlik"])
        #expect(model.undoable == nil)
    }
}
