import Foundation
import Testing
@testable import App

/// A gesture writes and re-reads the list before the tap ends, so that round trip has to fit inside a frame. It
/// covers the write, the re-read, and the layout `ListModel` does. SwiftUI's own drawing is not in it.
@MainActor @Suite struct GestureTimingTests {
    @Test func aCheckOnALongListWritesAndRedrawsWithinAFrame() throws {
        let store = try makeStore()
        let list = ShoppingList.main.id
        let names = Catalog.shared.products.prefix(300).map(\.name)
        store.add(names.compactMap { EntryParser.entries(in: $0).first }, to: list)
        let model = try #require(ListModel(listID: list, store: store))
        let ids = model.snapshot.items.map(\.id)
        #expect(ids.count == 300)

        let clock = ContinuousClock()
        var times: [Duration] = []
        var drawn = 0
        for id in ids.prefix(100) {
            times.append(clock.measure {
                model.toggle(id)
                drawn += model.sections.reduce(0) { $0 + $1.rows.count }
            })
        }
        let checked = try store.database.pool.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM items WHERE state = 'checked'") }
        #expect(checked == 100)
        #expect(drawn == 300 * 100)

        times.sort()
        let median = times[times.count / 2]
        print("gesture round trip: median \(median), fastest \(times[0]), slowest \(times[times.count - 1])")
        #expect(median < .milliseconds(16))
    }
}
