import Foundation
import GRDB

/// `category` shows aisle headers and infers categories. `none` is a plain list, such as packing, in added order.
enum Grouping: String, Sendable {
    case category, none
}

struct ShoppingList: SyncedRecord {
    static let table = "lists"
    /// The list every install has without a row. A row with this id exists only once the owner changed the list.
    static let main = ShoppingList(id: "main", name: "Groceries", grouping: .category, categoryOrder: [], position: 0, createdAt: .distantPast)

    var id: String
    var name: String
    var grouping: Grouping
    /// This list's aisle order. Categories it does not name follow in built-in order (`aisles`).
    var categoryOrder: [Category]
    var position: Double
    var createdAt: Date

    var key: String { id }

    /// Every category, this list's order first.
    var aisles: [Category] {
        var seen = Set<Category>()
        return (categoryOrder + Category.allCases).filter { seen.insert($0).inserted }
    }

    init(id: String, name: String, grouping: Grouping, categoryOrder: [Category], position: Double, createdAt: Date) {
        self.id = id
        self.name = name
        self.grouping = grouping
        self.categoryOrder = categoryOrder
        self.position = position
        self.createdAt = createdAt
    }

    init(row: Row) throws {
        id = row["id"]
        name = row["name"]
        // A grouping a newer app wrote reads as a plain list, which shows every item.
        grouping = Grouping(rawValue: row["grouping"]) ?? .none
        categoryOrder = try row.array("category_order", Category.init(rawValue:))
        position = row["position"]
        createdAt = try row.instant("created_at")
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["grouping"] = grouping.rawValue
        container["category_order"] = RowJSON.text(categoryOrder.map(\.rawValue))
        container["position"] = position
        container["created_at"] = Instant.text(createdAt)
    }
}
