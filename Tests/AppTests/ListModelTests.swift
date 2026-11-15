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

    @Test func hidingCheckedTakesThemOutAtOnceAndALaterCheckWaitsForTheScreenToSettle() throws {
        let model = try #require(ListModel(listID: list, store: store))
        defer { if model.hidesChecked { model.toggleHidingChecked() } }
        model.add("milk, bread, eggs")
        model.toggle(id("milk"))
        #expect(drawn(model.sections) == ["bakery: Bread", "dairy: Eggs, Milk"])

        model.toggleHidingChecked()
        #expect(drawn(model.sections) == ["bakery: Bread", "dairy: Eggs"])
        model.toggle(id("bread"))
        #expect(drawn(model.sections) == ["bakery: Bread", "dairy: Eggs"])

        model.toggleHidingChecked()
        #expect(drawn(model.sections) == ["bakery: Bread", "dairy: Eggs, Milk"])
        model.clearChecked()
        #expect(drawn(model.sections) == ["dairy: Eggs"])
        model.undo()
        #expect(drawn(model.sections) == ["bakery: Bread", "dairy: Eggs, Milk"])
    }

    @Test func aRenameCanBeTakenBackAndAnAmountEditOffersNothing() throws {
        let model = try #require(ListModel(listID: list, store: store))
        model.add("mlik")
        model.edit(id("mlik"), quantity: "2")
        #expect(model.undoable == nil)

        model.edit(id("mlik"), name: "Milk")
        #expect(model.undoable?.message == "Renamed to Milk")
        #expect(drawn(model.sections) == ["dairy: Milk"])
        model.undo()
        #expect(model.snapshot.items.map(\.name) == ["Mlik"])
        #expect(model.undoable == nil)
    }

    @Test(.timeLimit(.minutes(1))) func aListDeletedElsewhereSaysItIsGone() async throws {
        let camping = try #require(store.createList(named: "Camping", grouping: .none))
        let model = try #require(ListModel(listID: camping.id, store: store))
        await withCheckedContinuation { gone in
            model.onGone = { gone.resume() }
            store.deleteList(camping.id)
        }
        #expect(ListModel(listID: camping.id, store: store) == nil)
    }
}
