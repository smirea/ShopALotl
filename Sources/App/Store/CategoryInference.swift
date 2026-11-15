import Foundation
import GRDB
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Picks the aisle for a name the catalog and the owner's answers do not settle.
protocol CategoryModel: Sendable {
    /// False while the device can't run it: not eligible, Apple Intelligence off, or the model still downloading.
    var isAvailable: Bool { get }
    /// `corrections` are names the owner filed by hand, as examples of how they shop.
    func category(for name: String, corrections: [(name: String, category: Category)]) async throws -> Category?
}

#if canImport(FoundationModels)
/// Apple's on-device model, its output constrained to the category ids. Greedy sampling, so asking again about the
/// same name gives the same aisle.
struct OnDeviceCategoryModel: CategoryModel {
    private let model = SystemLanguageModel.default

    var isAvailable: Bool { model.isAvailable }

    func category(for name: String, corrections: [(name: String, category: Category)]) async throws -> Category? {
        var instructions = Self.instructions
        if !corrections.isEmpty {
            instructions += "\nThis shopper files: " + corrections.map { "\($0.name) under \($0.category.rawValue)" }.joined(separator: "; ") + "."
        }
        let session = LanguageModelSession(model: model, instructions: instructions)
        let pick = try await session.respond(to: "Item: \(name)", generating: CategoryPick.self, options: GenerationOptions(samplingMode: .greedy))
        return Category(rawValue: pick.content.category)
    }

    private static let instructions = """
        You file shopping list items under the store aisle where a shopper finds them. The aisles: produce (fresh \
        fruit, vegetables, herbs); bakery (bread, baked goods); deli (sliced meats, prepared foods, specialty cheese, \
        tofu); meat (fresh meat and poultry); seafood; dairy (milk, eggs, cheese, yogurt, butter, plant milks); frozen; \
        pantry (dry goods, cans, oils, sauces, condiments, spices, baking, nut butters); breakfast (cereal, oats, \
        granola); snacks (chips, crackers, candy, cookies); beverages (drinks without alcohol, coffee, tea); alcohol; \
        household (cleaning, paper goods, kitchen supplies, batteries); personal_care (toiletries, medicine, \
        vitamins); baby; pet; other (anything a grocery store does not sell in those aisles).
        """
}

@Generable
private struct CategoryPick {
    @Guide(description: "The aisle where a shopper finds the item", .anyOf(Category.allCases.map(\.rawValue)))
    var category: String
}
#endif

/// Asks the on-device model about every name on a categorized list whose aisle is still a guess, and stores the
/// answer as the model's (`CategorySource.model`), which syncs so a device without the model files the name the same
/// way. It never touches a list: the answer reaches the screen through `Categorizer` when the list next settles.
/// Without the model nothing happens and the guess stays.
@MainActor
final class CategoryInference {
    nonisolated static let log = Logger(subsystem: "com.stefan.shopalotl", category: "categories")

    struct Request: Equatable, Sendable {
        let key: NameKey
        let name: String
        let corrections: [Correction]
    }

    struct Correction: Equatable, Sendable {
        let name: String
        let category: Category
    }

    private let model: any CategoryModel
    private var store: LocalStore?
    private var observation: AnyDatabaseCancellable?
    private var queue: [Request] = []
    /// Names asked about this launch, so one the model fails on is not asked again until the next.
    private var asked: Set<NameKey> = []
    private var worker: Task<Void, Never>?

    init(model: any CategoryModel) {
        self.model = model
    }

    func start(store: LocalStore) {
        guard self.store == nil else { return }
        self.store = store
        observation = ValueObservation.tracking(Self.requests).removeDuplicates().start(
            in: store.database.pool,
            scheduling: .async(onQueue: .main),
            onError: { Self.log.error("Observing uncategorized names failed: \(String(describing: $0))") },
            onChange: { requests in MainActor.assumeIsolated { [weak self] in self?.receive(requests) } }
        )
    }

    /// Returns once every name that was waiting at the call has been asked about and its answer written, for tests.
    func idle() async {
        guard let store else { return }
        if let current = try? await store.database.pool.read(Self.requests) { receive(current) }
        while let worker { await worker.value }
    }

    /// Names on a categorized list that neither the owner, the catalog, nor an earlier model answer settles.
    nonisolated static let requests: @Sendable (Database) throws -> [Request] = { db in
        var requests: [NameKey: Request] = [:]
        for list in try ShoppingList.fetchAll(db) where list.grouping == .category {
            guard let snapshot = try ListSnapshot.fetch(db, listID: list.id) else { continue }
            let corrections = snapshot.answers.compactMap { key, answers in answers.user.map { Correction(name: key.text, category: $0) } }
                .sorted { $0.name < $1.name }.prefix(20)
            for item in snapshot.items where item.isOnList && Categorizer.place(item.id.key, answers: snapshot.answers).isSettled == false {
                requests[item.id.key] = Request(key: item.id.key, name: item.name, corrections: Array(corrections))
            }
        }
        return requests.values.sorted { $0.key.text < $1.key.text }
    }

    private func receive(_ requests: [Request]) {
        guard model.isAvailable else { return }
        let queued = Set(queue.map(\.key))
        queue += requests.filter { !asked.contains($0.key) && !queued.contains($0.key) }
        guard worker == nil, !queue.isEmpty else { return }
        worker = Task {
            while !queue.isEmpty {
                let request = queue.removeFirst()
                asked.insert(request.key)
                await answer(request)
            }
            worker = nil
        }
    }

    private func answer(_ request: Request) async {
        do {
            let corrections = request.corrections.map { (name: $0.name, category: $0.category) }
            guard let category = try await model.category(for: request.name, corrections: corrections) else {
                return Self.log.error("The model answered no known category for \(request.name, privacy: .public)")
            }
            store?.setCategory(category, for: request.key, source: .model)
        } catch {
            Self.log.error("Inferring a category failed: \(String(describing: error))")
        }
    }
}
