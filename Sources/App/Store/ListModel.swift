import Foundation
import GRDB
import Observation
import SwiftUI

/// One open list: what its screen draws and every gesture on it.
///
/// A gesture writes to the store and re-reads the list in the same turn, so the screen changes before the tap ends.
/// Rows hold still in between: a row keeps the section it was drawn in (`held`) until the list has been left alone
/// for `settleDelay`, so a checked row is struck through in place and a late category answer waits its turn. Only
/// the rows a gesture is about move at once: an added row, an edited one, one the owner refiled or brought back.
@MainActor @Observable
final class ListModel {
    static let settleDelay: Duration = .milliseconds(1500)

    let listID: String
    private(set) var snapshot: ListSnapshot
    private(set) var sections: [ListSection] = []
    /// The last gesture that can be taken back, shown as a toast until it expires.
    private(set) var undoable: Undoable?

    struct Undoable: Equatable {
        let id = UUID()
        let message: String
        let change: ItemChange
    }

    /// Called when the list no longer exists, such as after another device deleted it.
    @ObservationIgnored var onGone: () -> Void = {}

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private var held: [ItemID: SectionID] = [:]
    @ObservationIgnored private var lastTouch = ContinuousClock.now
    @ObservationIgnored private var settling: Task<Void, Never>?
    @ObservationIgnored private var expiring: Task<Void, Never>?
    @ObservationIgnored private var observation: AnyDatabaseCancellable?

    /// Nil when the list does not exist.
    init?(listID: String, store: LocalStore) {
        guard let snapshot = try? store.database.pool.read({ try ListSnapshot.fetch($0, listID: listID) }) else { return nil }
        self.listID = listID
        self.store = store
        self.snapshot = snapshot
        draw()
        observation = ValueObservation.tracking { try ListSnapshot.fetch($0, listID: listID) }.removeDuplicates().start(
            in: store.database.pool,
            scheduling: .async(onQueue: .main),
            onError: { LocalStore.log.error("Observing list \(listID) failed: \(String(describing: $0))") },
            onChange: { snapshot in MainActor.assumeIsolated { [weak self] in self?.receive(snapshot) } }
        )
    }

    var list: ShoppingList { snapshot.list }
    var isEmpty: Bool { sections.isEmpty }
    var checkedCount: Int { snapshot.items.count { $0.state == .checked } }
    /// On a list without categories nothing is known about a name but what the list itself remembers.
    private var catalog: Catalog? { list.grouping == .category ? .shared : nil }

    var due: [Suggestion] { Suggestions.due(items: snapshot.items, now: .now) }

    /// The add panel's rows for the field's text. Text with a separator adds several items, so only that is offered.
    func suggestions(for text: String) -> [Suggestion] {
        let entries = EntryParser.entries(in: text)
        guard let entry = entries.first else { return Suggestions.idle(items: snapshot.items, now: .now) }
        guard entries.count == 1 else { return [] }
        return Suggestions.matches(for: entry.name, items: snapshot.items, catalog: catalog, now: .now)
    }

    func item(_ id: ItemID) -> Item? { snapshot.items.first { $0.id == id } }

    /// Adds everything typed. False when the text holds no name.
    @discardableResult
    func add(_ text: String) -> Bool {
        let entries = EntryParser.entries(in: text)
        guard !entries.isEmpty else { return false }
        reload(releasing: store.add(entries, to: listID))
        return true
    }

    /// Adds a suggestion, with the amount and note typed before it was tapped: "3 mi", then a tap on Milk, is 3 Milk.
    func pick(_ suggestion: Suggestion, typed text: String) {
        let typed = EntryParser.entries(in: text).first
        let entry = Entry(key: suggestion.key, name: suggestion.name, quantity: typed?.quantity ?? "", note: typed?.note ?? "")
        reload(releasing: store.add([entry], to: listID))
    }

    func toggle(_ id: ItemID) {
        store.toggleChecked(id)
        reload()
    }

    func remove(_ id: ItemID) {
        guard let item = item(id) else { return }
        offerUndo(of: store.remove(id), "Removed \(item.name)")
        reload()
    }

    func clearChecked() {
        let change = store.clearChecked(in: listID)
        offerUndo(of: change, "Cleared \(change.rows.count) \(change.rows.count == 1 ? "item" : "items")")
        reload()
    }

    func forget(_ suggestion: Suggestion) {
        offerUndo(of: store.forget(ItemID(listID: listID, key: suggestion.key)), "Forgot \(suggestion.name)")
        reload()
    }

    func setCategory(_ category: Category, of id: ItemID) {
        store.setCategory(category, for: id.key)
        held[id] = nil
        reload()
    }

    /// Changes the fields that are not nil. A rename replaces the item's row, so it can be taken back.
    func edit(_ id: ItemID, name: String? = nil, quantity: String? = nil, note: String? = nil) {
        let change = store.edit(id, name: name, quantity: quantity, note: note)
        if let renamed = change.rows.last?.after, renamed.id != id { offerUndo(of: change, "Renamed to \(renamed.name)") }
        reload(releasing: change)
    }

    func undo() {
        guard let undoable else { return }
        self.undoable = nil
        reload(releasing: store.undo(undoable.change))
    }

    /// The owner touched or scrolled the list, so rows stay put a while longer.
    func touch() {
        lastTouch = .now
        if settling != nil { scheduleSettle() }
    }

    /// Redraws after a gesture. The rows `change` wrote go where they now belong, and every other row stays put.
    private func reload(releasing change: ItemChange = ItemChange()) {
        touch()
        for row in change.rows { held[row.id] = nil }
        do {
            receive(try store.database.pool.read { try ListSnapshot.fetch($0, listID: listID) })
        } catch {
            LocalStore.log.error("Reading list \(self.listID) failed: \(String(describing: error))")
        }
    }

    /// A change from the database: this screen's own write, or one from a sync or the category model.
    private func receive(_ fresh: ListSnapshot?) {
        guard let fresh else { return onGone() }
        guard fresh != snapshot else { return }
        withAnimation(.snappy(duration: 0.25)) {
            snapshot = fresh
            draw()
        }
    }

    private func draw() {
        let ideal = Layout.ideal(snapshot)
        held = held.filter { ideal[$0.key] != nil }.merging(ideal) { drawn, _ in drawn }
        sections = Layout.sections(snapshot, held: held)
        if held != ideal { scheduleSettle() }
    }

    private func scheduleSettle() {
        settling?.cancel()
        settling = Task { [weak self] in
            while let self, !Task.isCancelled {
                let wait = self.lastTouch + Self.settleDelay - .now
                guard wait > .zero else { return self.settle() }
                try? await Task.sleep(for: wait)
            }
        }
    }

    private func settle() {
        settling = nil
        held = [:]
        withAnimation(.snappy(duration: 0.35)) { draw() }
    }

    private func offerUndo(of change: ItemChange, _ message: String) {
        guard !change.isEmpty else { return }
        let offered = Undoable(message: message, change: change)
        undoable = offered
        expiring?.cancel()
        expiring = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled, self?.undoable == offered { self?.undoable = nil }
        }
    }
}
