import SwiftUI

/// One item on the list. The whole row is the check target.
struct ItemRowView: View {
    let row: ListRow
    let aisles: [Category]
    let model: ListModel
    var inlineCategory: Category? = nil
    let edit: () -> Void

    private var item: Item { row.item }
    private var isChecked: Bool { item.state == .checked }

    var body: some View {
        Button {
            model.toggle(item.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isChecked ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(isChecked)
                        .foregroundStyle(isChecked ? .secondary : .primary)
                    if !item.note.isEmpty {
                        Text(item.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if !item.quantity.isEmpty || inlineCategory != nil {
                    VStack(alignment: .trailing, spacing: 2) {
                        if !item.quantity.isEmpty {
                            Text(item.quantity)
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let inlineCategory {
                            HStack(spacing: 4) {
                                Image(systemName: inlineCategory.symbol)
                                    .accessibilityHidden(true)
                                Text(inlineCategory.title)
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                    }
                    .layoutPriority(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { model.remove(item.id) } label: { Label("Remove", systemImage: "trash") }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: edit) { Label("Edit", systemImage: "pencil") }.tint(.accentColor)
        }
        .contextMenu {
            Button(action: edit) { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { model.remove(item.id) } label: { Label("Remove", systemImage: "trash") }
            if let placement = row.placement {
                Picker("Aisle", selection: Binding(get: { placement.category }, set: { model.setCategory($0, of: item.id) })) {
                    ForEach(aisles) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
            }
        }
        .feedback(self)
    }
}
