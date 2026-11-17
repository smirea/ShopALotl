import Testing
@testable import App

@Suite struct CategorizerTests {
    private func key(_ name: String) -> NameKey { NameKey(name)! }

    private func place(_ name: String, _ answers: [String: CategoryAnswers] = [:]) -> Placement {
        Categorizer.place(key(name), answers: Dictionary(uniqueKeysWithValues: answers.map { (key($0.key), $0.value) }))
    }

    @Test(arguments: [
        ("milk", Category.dairy), ("Bananas", .produce), ("banana", .produce), ("Tomatoes", .produce), ("berry", .produce),
        ("Mints", .snacks), ("Mint", .produce), ("Crème fraîche", .dairy),
    ])
    func theCatalogSettlesNamesItKnows(name: String, category: Category) {
        #expect(place(name) == Placement(category: category, isSettled: true))
    }

    @Test func aNameTheCatalogOnlyKnowsPartOfIsAGuess() {
        #expect(place("barista oat milk") == Placement(category: .dairy, isSettled: false))
        #expect(place("organic chicken stir fry") == Placement(category: .meat, isSettled: false))
        #expect(place("cashew butter") == Placement(category: .dairy, isSettled: false))
    }

    @Test func anUnknownNameIsAnUnsettledOther() {
        #expect(place("flux capacitor") == Placement(category: .other, isSettled: false))
    }

    @Test func theOwnersAnswerBeatsTheCatalogAndTheModel() {
        let answers = ["milk": CategoryAnswers(user: .beverages, model: .frozen)]
        #expect(place("milk", answers) == Placement(category: .beverages, isSettled: true))
    }

    @Test func theCatalogBeatsTheModelAndTheModelBeatsAGuess() {
        #expect(place("milk", ["milk": CategoryAnswers(model: .frozen)]).category == .dairy)
        #expect(place("cashew butter", ["cashew butter": CategoryAnswers(model: .pantry)]) == Placement(category: .pantry, isSettled: true))
    }

    @Test func aCorrectionAlsoFilesLongerNamesThatEndWithIt() {
        let answers = ["oat milk": CategoryAnswers(user: .beverages)]
        #expect(place("barista oat milk", answers) == Placement(category: .beverages, isSettled: false))
    }

    @Test func everyCatalogNameHasAKeyAndTheCommonOnesAreUnique() {
        let products = Catalog.shared.products
        let duplicates = Dictionary(grouping: products, by: \.key).filter { $0.value.count > 1 }.keys.map(\.text).sorted()
        #expect(duplicates == [])
    }
}
