import Foundation

/// What each gesture does to one item row, as pure functions from the row before to the row after. Nil is no row.
enum Edits {
    /// An uncheck this soon after the check was a slip, so the purchase is taken back. Later, it means the item is
    /// needed again and the purchase stands.
    static let slipWindow: TimeInterval = 6 * 3600

    /// Typing a name that is already remembered brings its row back with its usual amount. Typing one that is on the
    /// list only updates the amount or note that was typed with it.
    static func added(_ entry: Entry, to listID: String, existing: Item?, at now: Date) -> Item {
        guard var item = existing else {
            return Item(id: ItemID(listID: listID, key: entry.key), name: entry.name, quantity: entry.quantity, note: entry.note, addedAt: now)
        }
        if item.state != .needed {
            item.state = .needed
            item.addedAt = now
            item.name = entry.name
        }
        if !entry.quantity.isEmpty { item.quantity = entry.quantity }
        if !entry.note.isEmpty { item.note = entry.note }
        return item
    }

    static func toggled(_ item: Item, at now: Date) -> Item {
        var item = item
        switch item.state {
        case .needed:
            item.state = .checked
            item.bought = Array((item.bought + [now]).suffix(Item.maxBought))
        case .checked:
            item.state = .needed
            if let last = item.bought.last, now.timeIntervalSince(last) < slipWindow { item.bought.removeLast() }
        case .off:
            break
        }
        return item
    }

    /// Off the list. An item that was bought before stays remembered for suggestions; one that never was leaves
    /// nothing behind, so a typo does not become a suggestion.
    static func removed(_ item: Item) -> Item? {
        guard !item.bought.isEmpty else { return nil }
        var item = item
        item.state = .off
        return item
    }

    static func cleared(_ item: Item) -> Item {
        var item = item
        if item.state == .checked { item.state = .off }
        return item
    }

    /// The rows after an edit. Nil leaves a field as the row has it now, so a field another device changed while the
    /// editor was open survives. A new name with another key moves the item to that key's row, with the purchases
    /// of both, because the id holds the key.
    static func edited(_ item: Item, name: String?, quantity: String?, note: String?, existingAtNewKey: Item?) -> (old: Item?, new: Item)? {
        var edited = item
        if let name { edited.name = name.trimmingCharacters(in: .whitespaces) }
        if let quantity { edited.quantity = quantity }
        if let note { edited.note = note }
        guard let key = NameKey(edited.name) else { return nil }
        guard key != item.id.key else { return (edited, edited) }
        let bought = Array(Set(item.bought + (existingAtNewKey?.bought ?? [])).sorted().suffix(Item.maxBought))
        let moved = Item(
            id: ItemID(listID: item.id.listID, key: key), name: edited.name, state: item.state, quantity: edited.quantity,
            note: edited.note, addedAt: item.addedAt, bought: bought
        )
        return (nil, moved)
    }
}
