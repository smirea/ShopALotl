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

enum DisplayRow: Identifiable, Equatable, Sendable {
    case header(Category)
    case item(ListRow, inlineCategory: Category?, showsDividerAbove: Bool)

    enum ID: Hashable, Sendable {
        case header(Category)
        case item(ItemID)
    }

    var id: ID {
        switch self {
        case let .header(category): .header(category)
        case let .item(row, _, _): .item(row.id)
        }
    }
}

/// Arranges a list's items into sections. A checked item stays in its aisle, struck through, so checking never moves
/// a row. Where a row belongs (`ideal`) is kept apart from where it is drawn (`sections(_:held:)`): a row stays where
/// it was drawn until the screen settles, so a late category answer, or a check while checked items are hidden, never
/// moves a row out from under a tap.
enum Layout {
    static func placement(of item: Item, in snapshot: ListSnapshot, catalog: Catalog = .shared) -> Placement? {
        snapshot.list.grouping == .category ? Categorizer.place(item.id.key, answers: snapshot.answers, catalog: catalog) : nil
    }

    /// The section each shown item belongs in.
    static func ideal(_ snapshot: ListSnapshot, hidingChecked: Bool = false, catalog: Catalog = .shared) -> [ItemID: SectionID] {
        var sections: [ItemID: SectionID] = [:]
        for item in snapshot.items where item.isOnList && !(hidingChecked && item.state == .checked) {
            sections[item.id] = placement(of: item, in: snapshot, catalog: catalog).map { .aisle($0.category) } ?? .plain
        }
        return sections
    }

    /// The sections as drawn: each item on the list in `held`'s section when it has one, else where it belongs.
    /// Aisles follow the list's order with items by name, and a plain list keeps added order.
    static func sections(
        _ snapshot: ListSnapshot, held: [ItemID: SectionID] = [:], hidingChecked: Bool = false, catalog: Catalog = .shared
    ) -> [ListSection] {
        let ideal = ideal(snapshot, hidingChecked: hidingChecked, catalog: catalog)
        var rows: [SectionID: [ListRow]] = [:]
        for item in snapshot.items where item.isOnList {
            guard let section = held[item.id] ?? ideal[item.id] else { continue }
            rows[section, default: []].append(ListRow(item: item, placement: placement(of: item, in: snapshot, catalog: catalog)))
        }
        let order: [SectionID] = snapshot.list.aisles.map(SectionID.aisle) + [.plain]
        return order.compactMap { id in
            guard let unsorted = rows[id] else { return nil }
            let sorted = switch id {
            case .aisle: unsorted.sorted { $0.item.name.localizedStandardCompare($1.item.name) == .orderedAscending }
            case .plain: unsorted.sorted { ($0.item.addedAt, $0.item.id.text) < ($1.item.addedAt, $1.item.id.text) }
            }
            return ListSection(id: id, rows: sorted)
        }
    }

    /// Flattens drawn sections into list rows. An aisle with one item omits its header and shows its category inline
    /// on the item; the first inline item after a headed aisle carries a top divider so the group boundary stays clear.
    static func displayRows(from sections: [ListSection]) -> [DisplayRow] {
        var result: [DisplayRow] = []
        var previousWasHeaded = false
        for section in sections where !section.rows.isEmpty {
            switch section.id {
            case .plain:
                previousWasHeaded = false
                for row in section.rows {
                    result.append(.item(row, inlineCategory: nil, showsDividerAbove: false))
                }
            case let .aisle(category):
                if section.rows.count == 1, let only = section.rows.first {
                    result.append(.item(only, inlineCategory: category, showsDividerAbove: previousWasHeaded))
                    previousWasHeaded = false
                } else {
                    result.append(.header(category))
                    for row in section.rows {
                        result.append(.item(row, inlineCategory: nil, showsDividerAbove: false))
                    }
                    previousWasHeaded = true
                }
            }
        }
        return result
    }
}
