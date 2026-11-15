import Foundation

/// The stored answers about one name: the owner's and the on-device model's.
struct CategoryAnswers: Equatable, Sendable {
    var user: Category?
    var model: Category?
}

/// Where a name is filed and how sure that is.
struct Placement: Equatable, Sendable {
    let category: Category
    /// False when nothing knows the name and the category is a guess from part of it, or `other`. Only guesses are
    /// worth asking the model about.
    let isSettled: Bool
}

/// Files a name under a category. The order of its sources is the policy: the owner's answer, the catalog's entry for
/// the whole name, the model's stored answer, then a guess from part of the name against the owner's answers and
/// the catalog.
enum Categorizer {
    static func place(_ key: NameKey, answers: [NameKey: CategoryAnswers], catalog: Catalog = .shared) -> Placement {
        let own = answers[key]
        if let category = own?.user { return Placement(category: category, isSettled: true) }
        if let product = catalog.product(for: key) { return Placement(category: product.category, isSettled: true) }
        if let category = own?.model { return Placement(category: category, isSettled: true) }
        let guess = ownerHead(key, answers: answers) ?? catalog.headCategory(for: key)
        return Placement(category: guess ?? .other, isSettled: false)
    }

    /// The owner's answer for the longest run of words at the end of the name, so a fix for "oat milk" also files
    /// "barista oat milk".
    private static func ownerHead(_ key: NameKey, answers: [NameKey: CategoryAnswers]) -> Category? {
        let words = key.words
        guard words.count > 1 else { return nil }
        for length in stride(from: words.count - 1, through: 1, by: -1) {
            if let head = NameKey(stored: words.suffix(length).joined(separator: " ")), let category = answers[head]?.user { return category }
        }
        return nil
    }
}
