import Foundation
import Testing
@testable import App

@Suite struct LayoutTests {
    private func item(_ name: String, state: ItemState = .needed, added: TimeInterval = 0, bought: [TimeInterval] = []) -> Item {
        Item(id: ItemID(listID: "main", key: NameKey(name)!), name: name, state: state, addedAt: .at(added), bought: bought.map(Date.at))
    }

    private func snapshot(_ items: [Item], grouping: Grouping = .category, order: [App.Category] = [], answers: [NameKey: CategoryAnswers] = [:]) -> ListSnapshot {
        var list = ShoppingList.main
        list.grouping = grouping
        list.categoryOrder = order
        return ListSnapshot(list: list, items: items, answers: answers)
    }

    @Test func itemsGroupUnderAislesInStoreOrderByNameWithCheckedLast() {
        let items = [
            item("Milk"), item("Bananas"), item("apples"), item("Eggs", state: .checked, bought: [5]),
            item("Bread", state: .checked, bought: [9]), item("Rice", state: .off, bought: [1]),
        ]
        #expect(drawn(Layout.sections(snapshot(items))) == ["produce: apples, Bananas", "dairy: Milk", "checked: Bread, Eggs"])
    }

    @Test func aListsOwnAisleOrderComesFirst() {
        let sections = Layout.sections(snapshot([item("Milk"), item("Bananas"), item("Bread")], order: [.dairy]))
        #expect(drawn(sections) == ["dairy: Milk", "produce: Bananas", "bakery: Bread"])
    }

    @Test func aPlainListKeepsAddedOrderWithoutAisles() {
        let items = [item("Tent", added: 2), item("Bananas", added: 1), item("Stove", state: .checked, added: 0, bought: [3])]
        #expect(drawn(Layout.sections(snapshot(items, grouping: .none))) == ["plain: Bananas, Tent", "checked: Stove"])
    }

    @Test func aRowStaysWhereItWasDrawnUntilTheScreenSettles() {
        let before = snapshot([item("Milk"), item("Flux capacitor")])
        let held = Layout.ideal(before)
        #expect(drawn(Layout.sections(before, held: held)) == ["dairy: Milk", "other: Flux capacitor"])

        let key = NameKey("Flux capacitor")!
        let after = snapshot([item("Milk", state: .checked, bought: [1]), item("Flux capacitor"), item("Eggs")], answers: [key: CategoryAnswers(model: .pantry)])
        #expect(drawn(Layout.sections(after, held: held)) == ["dairy: Eggs, Milk", "other: Flux capacitor"])
        #expect(drawn(Layout.sections(after)) == ["dairy: Eggs", "pantry: Flux capacitor", "checked: Milk"])
    }

    @Test func aHeldRowThatLeftTheListIsNotDrawn() {
        let held = Layout.ideal(snapshot([item("Milk")]))
        #expect(Layout.sections(snapshot([item("Milk", state: .off, bought: [1])]), held: held).isEmpty)
    }
}
