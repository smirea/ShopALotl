import Feedback
import GRDB
import SwiftUI

@main
struct ShopALotlApp: App {
    @State private var store: LocalStore

    init() {
        let store = LocalStore()
        _store = State(initialValue: store)
        #if canImport(UIKit)
        Feedback.enable()
        Feedback.webhooks = [
            FeedbackWebhook(
                name: "GitHub Issue",
                url: AppEnvironment.apiURL.appending(path: "api/feedback"),
                image: Feedback.githubIcon,
                headers: ["Authorization": "Bearer \(AppEnvironment.ownerToken)"]
            ),
        ]
        Feedback.context("Sync") {
            (
                api: AppEnvironment.apiURL.absoluteString, status: String(describing: store.syncStatus),
                unsyncedChanges: store.unsyncedChanges, cursor: store.cursor
            )
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

struct ContentView: View {
    @Environment(LocalStore.self) private var store
    @Observe(DatabaseQuery([Item]()) { try Item.readable($0, sql: "SELECT * FROM items WHERE state != 'off' ORDER BY added_at") })
    private var items
    @State private var text = ""

    var body: some View {
        NavigationStack {
            List(items) { item in
                Button {
                    store.write { db in
                        var changed = item
                        changed.state = item.state == .checked ? .needed : .checked
                        try changed.updateChanges(db, from: item)
                    }
                } label: {
                    Label(item.name, systemImage: item.state == .checked ? "checkmark.circle.fill" : "circle")
                }
            }
            .navigationTitle(ShoppingList.main.name)
            .safeAreaInset(edge: .bottom) {
                TextField("Add item", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onSubmit(add)
            }
        }
        .feedback(self)
    }

    private func add() {
        guard let key = NameKey(text) else { return }
        let item = Item(id: ItemID(listID: ShoppingList.main.id, key: key), name: text.trimmingCharacters(in: .whitespaces), addedAt: .now)
        store.write { try item.save($0) }
        text = ""
    }
}
