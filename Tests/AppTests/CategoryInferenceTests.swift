import Foundation
import Testing
@testable import App

private struct FakeModel: CategoryModel {
    var isAvailable = true
    let answers: [String: App.Category]
    let asked = Asked()

    final class Asked: @unchecked Sendable {
        private let lock = NSLock()
        private var names: [String] = []
        func record(_ name: String) { lock.withLock { names.append(name) } }
        var all: [String] { lock.withLock { names } }
    }

    func category(for name: String, corrections: [(name: String, category: App.Category)]) async throws -> App.Category? {
        asked.record(name)
        return answers[name]
    }
}

@MainActor @Suite struct CategoryInferenceTests {
    private func run(_ model: FakeModel, adding text: String, grouping: Grouping = .category) async throws -> [String: CategoryAnswers] {
        let store = try makeStore()
        if grouping == .none { store.updateList(ShoppingList.main.id) { $0.grouping = .none } }
        store.add(EntryParser.entries(in: text), to: ShoppingList.main.id)
        let inference = CategoryInference(model: model)
        inference.start(store: store)
        await inference.idle()
        let snapshot = try #require(try await store.database.pool.read { try ListSnapshot.fetch($0, listID: ShoppingList.main.id) })
        return Dictionary(uniqueKeysWithValues: snapshot.answers.map { ($0.key.text, $0.value) })
    }

    @Test func onlyNamesNothingElseSettlesAreAskedAndTheAnswerIsStoredAsTheModels() async throws {
        let model = FakeModel(answers: ["Flux capacitor": .household, "Cashew butter": .pantry])
        let answers = try await run(model, adding: "milk, flux capacitor, cashew butter")
        #expect(model.asked.all.sorted() == ["Cashew butter", "Flux capacitor"])
        #expect(answers == ["flux capacitor": CategoryAnswers(model: .household), "cashew butter": CategoryAnswers(model: .pantry)])
    }

    @Test func withoutTheModelNothingIsAskedOrStored() async throws {
        let model = FakeModel(isAvailable: false, answers: [:])
        #expect(try await run(model, adding: "flux capacitor").isEmpty)
        #expect(model.asked.all.isEmpty)
    }

    @Test func aListWithoutCategoriesAsksNothing() async throws {
        let model = FakeModel(answers: ["Tent": .other])
        #expect(try await run(model, adding: "tent", grouping: .none).isEmpty)
        #expect(model.asked.all.isEmpty)
    }
}
