import Foundation

/// Everything one list screen shows, read in one transaction.
struct ListSnapshot: Equatable, Sendable {
    var list: ShoppingList
    /// Every row of the list, the remembered ones included.
    var items: [Item]
    var answers: [NameKey: CategoryAnswers]
}

enum SectionID: Hashable, Sendable {
    case aisle(Category)
    /// The one section of a list without categories.
    case plain
    case checked
}

struct ListRow: Identifiable, Equatable, Sendable {
    let item: Item
    /// Nil on a list without categories.
    let placement: Placement?

    var id: ItemID { item.id }
}

struct ListSection: Identifiable, Equatable, Sendable {
    let id: SectionID
    var rows: [ListRow]
}

/// Arranges a list's items into sections. Where a row belongs (`ideal`) is kept apart from where it is drawn
/// (`sections(_:held:)`): a row stays in the section it was drawn in until the screen settles, so a row never moves
/// out from under a tap when it is checked or when the model answers late.
enum Layout {
    static func placement(of item: Item, in snapshot: ListSnapshot, catalog: Catalog = .shared) -> Placement? {
        snapshot.list.grouping == .category ? Categorizer.place(item.id.key, answers: snapshot.answers, catalog: catalog) : nil
    }

    /// The section each item on the list belongs in.
    static func ideal(_ snapshot: ListSnapshot, catalog: Catalog = .shared) -> [ItemID: SectionID] {
        var sections: [ItemID: SectionID] = [:]
        for item in snapshot.items where item.isOnList {
            sections[item.id] = if item.state == .checked {
                .checked
            } else if let placement = placement(of: item, in: snapshot, catalog: catalog) {
                .aisle(placement.category)
            } else {
                .plain
            }
        }
        return sections
    }

    /// The sections as drawn: each item in `held`'s section when it has one, else where it belongs. Aisles follow
    /// the list's order with items by name, a plain list keeps added order, and checked items come last, the
    /// latest check first.
    static func sections(_ snapshot: ListSnapshot, held: [ItemID: SectionID] = [:], catalog: Catalog = .shared) -> [ListSection] {
        let ideal = ideal(snapshot, catalog: catalog)
        var rows: [SectionID: [ListRow]] = [:]
        for item in snapshot.items {
            guard let section = held[item.id] ?? ideal[item.id], ideal[item.id] != nil else { continue }
            rows[section, default: []].append(ListRow(item: item, placement: placement(of: item, in: snapshot, catalog: catalog)))
        }
        let order: [SectionID] = snapshot.list.aisles.map(SectionID.aisle) + [.plain, .checked]
        return order.compactMap { id in
            guard let unsorted = rows[id] else { return nil }
            let sorted = switch id {
            case .aisle: unsorted.sorted { $0.item.name.localizedStandardCompare($1.item.name) == .orderedAscending }
            case .plain: unsorted.sorted { ($0.item.addedAt, $0.item.id.text) < ($1.item.addedAt, $1.item.id.text) }
            case .checked: unsorted.sorted { ($0.item.bought.last ?? .distantPast, $1.item.id.text) > ($1.item.bought.last ?? .distantPast, $0.item.id.text) }
            }
            return ListSection(id: id, rows: sorted)
        }
    }
}
