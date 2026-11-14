import Foundation
import GRDB

enum CategorySource: String, Sendable {
    case user, model
}

/// One source's answer to "which category is this name". The owner and the on-device model each have their own row,
/// so a model answer that syncs late cannot replace a correction.
struct CategoryAnswer: SyncedRecord {
    static let table = "item_categories"

    var nameKey: NameKey
    var source: CategorySource
    var category: Category

    var id: String { "\(nameKey.text)#\(source.rawValue)" }
    var key: String { id }

    init(nameKey: NameKey, source: CategorySource, category: Category) {
        self.nameKey = nameKey
        self.source = source
        self.category = category
    }

    init(row: Row) throws {
        guard let nameKey = NameKey(stored: row["name_key"]), let source = CategorySource(rawValue: row["source"]),
              let category = Category(rawValue: row["category"])
        else { throw RowDecodingError(description: "Unreadable category answer \(row["id"] as String)") }
        self.nameKey = nameKey
        self.source = source
        self.category = category
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name_key"] = nameKey.text
        container["source"] = source.rawValue
        container["category"] = category.rawValue
    }
}
