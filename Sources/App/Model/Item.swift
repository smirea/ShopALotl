import Foundation
import GRDB

/// An item's identity: the list it is on and the key of its name. The row id and the `list_id` column are both
/// derived from it, so they cannot disagree.
struct ItemID: Hashable, Sendable, CustomStringConvertible {
    let listID: String
    let key: NameKey

    init(listID: String, key: NameKey) {
        self.listID = listID
        self.key = key
    }

    /// List ids hold no slash (`main` or a UUID), so the first one ends the list id.
    init?(text: String) {
        guard let slash = text.firstIndex(of: "/"), let key = NameKey(stored: String(text[text.index(after: slash)...])) else { return nil }
        listID = String(text[..<slash])
        self.key = key
    }

    var text: String { "\(listID)/\(key.text)" }
    var description: String { text }
}

/// `needed` and `checked` are on the list. `off` is remembered for suggestions only.
enum ItemState: String, Sendable {
    case needed, checked, off
}

/// Another of the owner's apps that put an item on the list, and what in it did: A Better Me and a recipe.
struct ItemSource: Hashable, Codable, Sendable {
    /// The app's id, such as `a-better-me`. One this version does not know shows with a generic icon.
    var app: String
    var id: String
    var title: String
}

/// One thing on one list, for as long as the list remembers it: the list entry, the autocomplete entry, and the
/// purchase history in one row.
struct Item: SyncedRecord {
    static let table = "items"
    /// How many purchases a row keeps (`MAX_BOUGHT` in `server/schema.ts`).
    static let maxBought = 12

    var id: ItemID
    /// As last typed.
    var name: String
    var state: ItemState
    /// Display text, `""` for none.
    var quantity: String
    var note: String
    /// When it last went onto the list.
    var addedAt: Date
    /// When it was checked off, ascending, at most `maxBought`.
    var bought: [Date]
    /// What other apps put it on the list for, oldest first. Empty for an item the owner typed.
    var sources: [ItemSource]

    var key: String { id.text }
    var isOnList: Bool { state != .off }

    init(id: ItemID, name: String, state: ItemState = .needed, quantity: String = "", note: String = "", addedAt: Date, bought: [Date] = [], sources: [ItemSource] = []) {
        self.id = id
        self.name = name
        self.state = state
        self.quantity = quantity
        self.note = note
        self.addedAt = addedAt
        self.bought = bought
        self.sources = sources
    }

    init(row: Row) throws {
        let text: String = row["id"]
        guard let id = ItemID(text: text) else { throw RowDecodingError(description: "Not an item id: \(text)") }
        guard let state = ItemState(rawValue: row["state"]) else { throw RowDecodingError(description: "Unknown item state in \(text)") }
        self.id = id
        self.state = state
        name = row["name"]
        quantity = row["quantity"]
        note = row["note"]
        addedAt = try row.instant("added_at")
        bought = try row.array("bought", Instant.parse)
        // A source another app version wrote in a shape this one cannot read drops them all, which only hides an icon.
        sources = (try? JSONDecoder().decode([ItemSource].self, from: Data((row["sources"] as String? ?? "[]").utf8))) ?? []
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id.text
        container["list_id"] = id.listID
        container["name"] = name
        container["state"] = state.rawValue
        container["quantity"] = quantity
        container["note"] = note
        container["added_at"] = Instant.text(addedAt)
        container["bought"] = RowJSON.text(bought.map(Instant.text))
        container["sources"] = ItemSource.text(sources)
    }
}

extension ItemSource {
    /// Sorted keys, so re-saving unchanged sources writes the same text and fires no update trigger.
    static func text(_ sources: [ItemSource]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: (try? encoder.encode(sources)) ?? Data("[]".utf8), as: UTF8.self)
    }
}
