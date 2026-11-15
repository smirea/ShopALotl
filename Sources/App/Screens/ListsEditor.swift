import SwiftUI
import SyncEngine

/// Every list, with a row to add one. Tapping a list opens its settings.
struct ListsEditor: View {
    @Environment(LocalStore.self) private var store
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Observe(ShoppingList.all) private var lists
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(lists) { list in
                        NavigationLink(value: list.id) {
                            Label(list.name, systemImage: list.grouping == .category ? "cart" : "checklist")
                        }
                    }
                    .onMove(perform: move)
                }
                Section {
                    Button { create(.category) } label: { Label("New Shopping List", systemImage: "cart.badge.plus") }
                    Button { create(.none) } label: { Label("New Plain List", systemImage: "plus") }
                } footer: {
                    Text("A shopping list sorts items by aisle. A plain list, such as a packing list, keeps the order you add them in.")
                }
                Section("Sync") {
                    LabeledContent("Status", value: syncStatus)
                }
            }
            .navigationTitle("Lists")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: String.self) { id in
                if let list = lists.first(where: { $0.id == id }) { ListSettings(list: list) }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .feedback(self)
    }

    private var syncStatus: String {
        let waiting = store.unsyncedChanges == 0 ? "" : " \(store.unsyncedChanges) changes waiting."
        switch store.syncStatus {
        case .offline: return "Offline." + waiting
        case .unauthorized: return "The server refused this build's token."
        case let .failed(reason): return "Failed: \(reason)." + waiting
        case .idle, .syncing:
            guard let last = store.lastSyncedAt else { return "Not synced yet." + waiting }
            return "Synced \(last.formatted(.relative(presentation: .named)))." + waiting
        }
    }

    private func create(_ grouping: Grouping) {
        guard let list = store.createList(named: grouping == .category ? "New List" : "New Plain List", grouping: grouping) else { return }
        app.open(list.id)
        path = [list.id]
    }

    /// A moved list takes a position between its new neighbors, so only its own row changes.
    private func move(from source: IndexSet, to destination: Int) {
        guard let index = source.first else { return }
        var reordered = lists
        reordered.move(fromOffsets: source, toOffset: destination)
        let moved = lists[index]
        guard let landed = reordered.firstIndex(of: moved) else { return }
        let before = landed > 0 ? reordered[landed - 1].position : (reordered.dropFirst().first?.position ?? 0) - 1
        let after = landed < reordered.count - 1 ? reordered[landed + 1].position : before + 2
        store.updateList(moved.id) { $0.position = (before + after) / 2 }
    }
}

/// One list's name, whether it sorts by aisle, and the order of its aisles.
struct ListSettings: View {
    let list: ShoppingList

    @Environment(LocalStore.self) private var store
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var confirmingDelete = false

    init(list: ShoppingList) {
        self.list = list
        _name = State(initialValue: list.name)
    }

    var body: some View {
        List {
            Section("Name") {
                TextField("Name", text: $name)
                    .onChange(of: name) { _, name in
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { store.updateList(list.id) { $0.name = trimmed } }
                    }
            }
            Section {
                Toggle("Sort by Aisle", isOn: Binding(
                    get: { list.grouping == .category },
                    set: { sorted in store.updateList(list.id) { $0.grouping = sorted ? .category : .none } }
                ))
            }
            if list.grouping == .category {
                Section {
                    ForEach(list.aisles) { Label($0.title, systemImage: $0.symbol) }
                        .onMove { source, destination in
                            var aisles = list.aisles
                            aisles.move(fromOffsets: source, toOffset: destination)
                            store.updateList(list.id) { $0.categoryOrder = aisles }
                        }
                } header: {
                    Text("Aisle Order")
                } footer: {
                    Text("Drag the aisles into the order you walk this store.")
                }
            }
            if list.id != ShoppingList.main.id {
                Section {
                    Button("Delete List", role: .destructive) { confirmingDelete = true }
                }
            }
        }
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
        .navigationTitle(list.name)
        .confirmationDialog("Delete \(list.name) and everything it remembers?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete List", role: .destructive) {
                app.open(ShoppingList.main.id)
                store.deleteList(list.id)
                dismiss()
            }
        }
        .feedback(self)
    }
}
