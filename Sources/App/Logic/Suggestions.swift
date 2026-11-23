import Foundation

/// One row of the add panel, or one chip of the due rail.
struct Suggestion: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        /// The text as typed, which Return adds.
        case typed
        /// Bought before and off the list.
        case remembered
        /// Known from the catalog only.
        case catalog
        case onList
        case checked
    }

    let key: NameKey
    let name: String
    /// The usual amount, offered again when a remembered item is re-added.
    let quantity: String
    let status: Status

    var id: String { key.text }
}

/// What to offer in the add panel. Pure functions over the list's rows, cheap enough to run on every keystroke.
enum Suggestions {
    /// Staples that are due: bought on a rhythm, off the list, and at least 80% through their usual interval. An item
    /// more than three intervals overdue is a habit that stopped, so it is left out.
    static func due(items: [Item], now: Date, limit: Int = 12) -> [Suggestion] {
        items.compactMap { item -> (Suggestion, Double)? in
            guard item.state == .off else { return nil }
            let habit = Habit(bought: item.bought)
            guard let dueness = habit.dueness(at: now), dueness >= 0.8, dueness <= 3 else { return nil }
            return (suggestion(item), min(dueness, 1.5) * log2(1 + Double(habit.count)))
        }
        .sorted { ($0.1, $1.0.name) > ($1.1, $0.0.name) }
        .prefix(limit).map(\.0)
    }

    /// Matches for a typed name, best first. The typed text itself leads unless something already has its key, so
    /// what Return adds is always the first row. Remembered items come before catalog entries at the same match
    /// quality, and items already on the list come last unless they are the exact match.
    static func matches(for name: String, items: [Item], catalog: Catalog?, now: Date, limit: Int = 20) -> [Suggestion] {
        guard let query = NameKey(name) else { return [] }
        var ranked: [(suggestion: Suggestion, order: (Int, Int, Int, Double))] = []
        var seen = Set<NameKey>()
        for item in items {
            guard let tier = tier(of: query, in: item.id.key) else { continue }
            seen.insert(item.id.key)
            let demoted = item.isOnList && tier != 0 ? 1 : 0
            ranked.append((suggestion(item), (demoted, tier, 0, -Habit.frecency(bought: item.bought, at: now))))
        }
        for product in catalog?.products ?? [] where !seen.contains(product.key) {
            guard let tier = tier(of: query, in: product.key) else { continue }
            let suggestion = Suggestion(key: product.key, name: product.name, quantity: "", status: .catalog)
            ranked.append((suggestion, (0, tier, 1, Double(product.rank))))
        }
        ranked.sort { ($0.order.0, $0.order.1, $0.order.2, $0.order.3, $0.suggestion.name) < ($1.order.0, $1.order.1, $1.order.2, $1.order.3, $1.suggestion.name) }
        var result = ranked.prefix(limit).map(\.suggestion)
        if !result.contains(where: { $0.key == query }) {
            result.insert(Suggestion(key: query, name: EntryParser.displayName(name.trimmingCharacters(in: .whitespaces)), quantity: "", status: .typed), at: 0)
        }
        return result
    }

    /// 0 the same name, 1 the name starts with the query, 2 a later word starts with it, 3 it appears inside a word.
    private static func tier(of query: NameKey, in key: NameKey) -> Int? {
        if key == query { return 0 }
        if key.text.hasPrefix(query.text) { return 1 }
        if key.text.contains(" " + query.text) { return 2 }
        if key.text.contains(query.text) { return 3 }
        return nil
    }

    private static func suggestion(_ item: Item) -> Suggestion {
        let status: Suggestion.Status = switch item.state {
        case .needed: .onList
        case .checked: .checked
        case .off: .remembered
        }
        return Suggestion(key: item.id.key, name: item.name, quantity: item.quantity, status: status)
    }
}
