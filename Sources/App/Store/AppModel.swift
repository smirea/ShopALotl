import Foundation
import Observation

/// Which list is open. Created before the first frame, so the app opens straight into the last list with its rows.
@MainActor @Observable
final class AppModel {
    private static let defaultsKey = "currentList"

    private(set) var current: ListModel
    @ObservationIgnored private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? ShoppingList.main.id
        // The first list exists without a row, so the fallback always opens.
        current = ListModel(listID: saved, store: store) ?? ListModel(listID: ShoppingList.main.id, store: store)!
        watch(current)
    }

    func open(_ listID: String) {
        guard listID != current.listID, let model = ListModel(listID: listID, store: store) else { return }
        current = model
        watch(model)
        UserDefaults.standard.set(listID, forKey: Self.defaultsKey)
    }

    /// A list deleted on another device closes here too, so nothing more is written to it.
    private func watch(_ model: ListModel) {
        model.onGone = { [weak self] in self?.open(ShoppingList.main.id) }
    }
}
