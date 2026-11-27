import SwiftUI

/// Edits one item. Changes are written when the sheet closes, so a half-typed name never syncs.
struct ItemEditor: View {
    let model: ListModel
    let id: ItemID

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var quantity: String
    @State private var note: String
    @State private var category: Category?
    private let original: Item
    private let originalCategory: Category?

    init?(model: ListModel, id: ItemID) {
        guard let item = model.item(id) else { return nil }
        self.model = model
        self.id = id
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
        _note = State(initialValue: item.note)
        original = item
        originalCategory = Layout.placement(of: item, in: model.snapshot)?.category
        _category = State(initialValue: originalCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    HStack {
                        TextField("Amount", text: $quantity)
                        Stepper("Amount", value: count, in: 1...99)
                            .labelsHidden()
                    }
                    TextField("Note", text: $note)
                }
                if !original.sources.isEmpty {
                    Section("Added From") {
                        ForEach(original.sources, id: \.self) { source in
                            Label {
                                Text(source.title.isEmpty ? SourceApp.name(source.app) : source.title)
                            } icon: {
                                SourceIcon(app: source.app, size: 20)
                            }
                        }
                    }
                }
                if category != nil {
                    Section {
                        Picker("Aisle", selection: $category) {
                            ForEach(model.list.aisles) { Label($0.title, systemImage: $0.symbol).tag(Optional($0)) }
                        }
                    }
                }
                Section {
                    Button("Remove from List", role: .destructive) {
                        model.remove(id)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save).disabled(NameKey(name) == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .feedback(self)
    }

    /// The stepper counts whole amounts and keeps a unit typed after the number: "2 cans" steps to "3 cans".
    private var count: Binding<Int> {
        let parts = quantity.split(separator: " ", maxSplits: 1)
        let unit = parts.count > 1 && Int(parts[0]) != nil ? " \(parts[1])" : ""
        return Binding(get: { parts.first.flatMap { Int($0) } ?? 1 }, set: { quantity = "\($0)\(unit)" })
    }

    /// Writes only the fields the owner changed, so one another device changed meanwhile is kept.
    private func save() {
        if let category, category != originalCategory, let key = NameKey(name) {
            model.setCategory(category, of: ItemID(listID: id.listID, key: key))
        }
        let quantity = quantity.trimmingCharacters(in: .whitespaces)
        let note = note.trimmingCharacters(in: .whitespaces)
        model.edit(
            id, name: name == original.name ? nil : name, quantity: quantity == original.quantity ? nil : quantity,
            note: note == original.note ? nil : note
        )
        dismiss()
    }
}
