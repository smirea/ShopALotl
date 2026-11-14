import Foundation

/// The aisles, in the order a store is usually walked. A list can reorder them (`ShoppingList.categoryOrder`).
/// The raw value is stored in synced rows, so a case's raw value never changes.
enum Category: String, CaseIterable, Identifiable, Sendable {
    case produce, bakery, deli, meat, seafood, dairy, frozen, pantry, breakfast, snacks, beverages, alcohol, household
    case personalCare = "personal_care"
    case baby, pet, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: "Produce"
        case .bakery: "Bakery"
        case .deli: "Deli"
        case .meat: "Meat"
        case .seafood: "Seafood"
        case .dairy: "Dairy & Eggs"
        case .frozen: "Frozen"
        case .pantry: "Pantry"
        case .breakfast: "Breakfast"
        case .snacks: "Snacks"
        case .beverages: "Beverages"
        case .alcohol: "Beer, Wine & Spirits"
        case .household: "Household"
        case .personalCare: "Personal Care"
        case .baby: "Baby"
        case .pet: "Pets"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .produce: "carrot"
        case .bakery: "birthday.cake"
        case .deli: "takeoutbag.and.cup.and.straw"
        case .meat: "fork.knife"
        case .seafood: "fish"
        case .dairy: "waterbottle"
        case .frozen: "snowflake"
        case .pantry: "cabinet"
        case .breakfast: "sunrise"
        case .snacks: "popcorn"
        case .beverages: "cup.and.saucer"
        case .alcohol: "wineglass"
        case .household: "house"
        case .personalCare: "comb"
        case .baby: "stroller"
        case .pet: "pawprint"
        case .other: "shippingbox"
        }
    }
}
