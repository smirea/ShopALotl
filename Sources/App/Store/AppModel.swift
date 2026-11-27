import Foundation
import Observation

/// Which list is open. Created before the first frame, so the app opens straight into the last list with its rows.
@MainActor @Observable
final class AppModel {
    private(set) var current: ListModel
    @ObservationIgnored private let store: LocalStore
    /// A list a link asked for before it synced here, such as one A Better Me just created, with when it was asked.
    @ObservationIgnored private var pending: (id: String, at: Date)?

    init(store: LocalStore) {
        self.store = store
        let saved = AppGroup.defaults.string(forKey: AppGroup.Key.currentList) ?? ShoppingList.main.id
        // The first list exists without a row, so the fallback always opens.
        current = ListModel(listID: saved, store: store) ?? ListModel(listID: ShoppingList.main.id, store: store)!
        watch(current)
    }

    func open(_ listID: String) {
        guard listID != current.listID, let model = ListModel(listID: listID, store: store) else { return }
        current = model
        watch(model)
        AppGroup.defaults.set(listID, forKey: AppGroup.Key.currentList)
        #if os(iOS)
        store.reloadWidget()
        #endif
    }

    /// Opens the list a link names. One this device does not have yet opens when it arrives, within a minute.
    func openLinked(_ listID: String, at now: Date = .now) {
        if ListModel(listID: listID, store: store) == nil {
            pending = (listID, now)
        } else {
            pending = nil
            open(listID)
        }
    }

    /// Called when the lists change, so a linked list that just synced opens.
    func openPending(at now: Date = .now) {
        guard let pending else { return }
        guard now.timeIntervalSince(pending.at) < 60 else {
            self.pending = nil
            return
        }
        openLinked(pending.id, at: pending.at)
    }

    /// A list deleted on another device closes here too, so nothing more is written to it.
    private func watch(_ model: ListModel) {
        model.onGone = { [weak self] in self?.open(ShoppingList.main.id) }
    }
}
