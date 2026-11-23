import Foundation
import Testing
@testable import App

@Suite struct SuggestionsTests {
    private let day: TimeInterval = 86_400
    private let now = Date.at(100 * 86_400)

    /// An item bought every `every` days, last `ago` days ago.
    private func item(_ name: String, state: ItemState = .off, every: Double = 7, ago: Double = 7, times: Int = 4, quantity: String = "") -> Item {
        let bought = (0..<times).reversed().map { now.addingTimeInterval(-(ago + Double($0) * every) * day) }
        return Item(id: ItemID(listID: "main", key: NameKey(name)!), name: name, state: state, quantity: quantity, addedAt: .at(0), bought: bought)
    }

    private let catalog = Catalog(source: [(.dairy, "Milk, Mozzarella, Oat milk"), (.produce, "Mint, Mushrooms")])

    @Test func staplesAreDueNearTheEndOfTheirUsualIntervalAndNotAfterTheHabitStopped() {
        let items = [
            item("Milk", every: 7, ago: 6), item("Eggs", every: 7, ago: 2), item("Rice", every: 30, ago: 200),
            item("Bread", state: .needed, every: 7, ago: 7), item("Salt", ago: 7, times: 1),
        ]
        #expect(Suggestions.due(items: items, now: now).map(\.name) == ["Milk"])
    }

    @Test func theMoreOverdueAndMoreOftenBoughtStapleComesFirst() {
        let items = [item("Milk", every: 7, ago: 6, times: 3), item("Eggs", every: 7, ago: 9, times: 3), item("Bread", every: 7, ago: 9, times: 10)]
        #expect(Suggestions.due(items: items, now: now).map(\.name) == ["Bread", "Eggs", "Milk"])
    }

    @Test func typingMatchesRememberedItemsBeforeTheCatalogAndLeadsWithTheTypedText() {
        let items = [item("Miso paste", quantity: "2"), item("Almond milk")]
        let matches = Suggestions.matches(for: "mi", items: items, catalog: catalog, now: now)
        #expect(matches.map(\.name) == ["Mi", "Miso paste", "Milk", "Mint", "Almond milk", "Oat milk"])
        #expect(matches.map(\.status) == [.typed, .remembered, .catalog, .catalog, .remembered, .catalog])
        #expect(matches[1].quantity == "2")
    }

    @Test func anExactMatchReplacesTheTypedRowAndAnItemOnTheListSaysSo() {
        let items = [item("Milk", state: .needed), item("Milk chocolate", state: .checked)]
        let matches = Suggestions.matches(for: "Milk", items: items, catalog: catalog, now: now)
        #expect(matches.map(\.name) == ["Milk", "Oat milk", "Milk chocolate"])
        #expect(matches.map(\.status) == [.onList, .catalog, .checked])
    }

    @Test func aPlainListSuggestsOnlyItsOwnItems() {
        let matches = Suggestions.matches(for: "m", items: [item("Matches")], catalog: nil, now: now)
        #expect(matches.map(\.name) == ["M", "Matches"])
        #expect(Suggestions.matches(for: "  ", items: [], catalog: catalog, now: now).isEmpty)
    }
}
