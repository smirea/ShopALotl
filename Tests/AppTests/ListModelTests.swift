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

    @Test func aCheckedRowKeepsItsSectionThroughOtherGesturesAndOnlyTheirOwnRowsMove() throws {
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

    @Test func aRowBroughtBackByUndoOrByAddingItAgainLeavesTheCheckedSection() throws {
        store.add(EntryParser.entries(in: "milk, bread"), to: list)
        store.toggleChecked(id("milk"))
        store.toggleChecked(id("bread"))
        let model = try #require(ListModel(listID: list, store: store))
        #expect(drawn(model.sections) == ["checked: Bread, Milk"])

        model.add("milk")
        #expect(drawn(model.sections) == ["dairy: Milk", "checked: Bread"])
        model.clearChecked()
        model.undo()
        #expect(drawn(model.sections) == ["dairy: Milk", "checked: Bread"])
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
