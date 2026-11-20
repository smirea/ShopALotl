import Foundation
import GRDB

/// The list's verbs. Each is one transaction, and each goes through `apply`, so every one can be undone.
extension LocalStore {
    @discardableResult
    func add(_ entries: [Entry], to listID: String, at now: Date = .now) -> ItemChange {
        change { db, change in
            for entry in entries {
                try ItemWrites.apply(db, ItemID(listID: listID, key: entry.key), to: &change) { Edits.added(entry, to: listID, existing: $0, at: now) }
            }
        }
    }

    @discardableResult
    func toggleChecked(_ id: ItemID, at now: Date = .now) -> ItemChange {
        change { db, change in change = try ItemWrites.toggle(db, id, at: now) }
    }

    @discardableResult
    func remove(_ id: ItemID) -> ItemChange {
        change { db, change in try ItemWrites.apply(db, id, to: &change) { $0.flatMap(Edits.removed) } }
    }

    /// Drops a remembered item, so it is no longer suggested.
    @discardableResult
    func forget(_ id: ItemID) -> ItemChange {
        change { db, change in try ItemWrites.apply(db, id, to: &change) { _ in nil } }
    }

    @discardableResult
    func clearChecked(in listID: String) -> ItemChange {
        change { db, change in
            let checked = try String.fetchAll(db, sql: "SELECT id FROM items WHERE list_id = ? AND state = 'checked'", arguments: [listID])
            for id in checked.compactMap(ItemID.init(text:)) {
                try ItemWrites.apply(db, id, to: &change) { $0.map(Edits.cleared) }
            }
        }
    }

    /// Changes the fields that are not nil. A name with another key moves the item to that key's row, so the change
    /// then holds two rows. A name without a key changes nothing.
    @discardableResult
    func edit(_ id: ItemID, name: String? = nil, quantity: String? = nil, note: String? = nil) -> ItemChange {
        change { db, change in
            guard let item = try Item.fetchOne(db, key: id.text) else { return }
            let target = ItemID(listID: id.listID, key: name.flatMap { NameKey($0) } ?? id.key)
            let existing = target == id ? nil : try Item.fetchOne(db, key: target.text)
            guard let edit = Edits.edited(item, name: name, quantity: quantity, note: note, existingAtNewKey: existing) else { return }
            try ItemWrites.apply(db, id, to: &change) { _ in edit.old }
            try ItemWrites.apply(db, target, to: &change) { _ in edit.new }
        }
    }

    /// Puts back what `change` replaced, row by row, newest first, because one change can touch a row twice. A row
    /// that no longer holds what the change wrote is left alone, so undo does not overwrite a newer change this
    /// device already has, and running it twice changes nothing more. A change another device made and has not
    /// synced yet still loses to the undo, as to any later write.
    @discardableResult
    func undo(_ undone: ItemChange) -> ItemChange {
        change { db, change in
            for row in undone.rows.reversed() {
                try ItemWrites.apply(db, row.id, to: &change) { $0 == row.after ? row.before : $0 }
            }
        }
    }

    /// The owner's correction, or the on-device model's answer, for a name on every list.
    func setCategory(_ category: Category, for key: NameKey, source: CategorySource = .user) {
        let answer = CategoryAnswer(nameKey: key, source: source, category: category)
        write { db in
            if let existing = try CategoryAnswer.fetchOne(db, key: answer.id) {
                try answer.updateChanges(db, from: existing)
            } else {
                try answer.insert(db)
            }
        }
    }

    @discardableResult
    private func change(_ body: (Database, inout ItemChange) throws -> Void) -> ItemChange {
        write { db in
            var change = ItemChange()
            try body(db, &change)
            return change
        } ?? ItemChange()
    }
}
