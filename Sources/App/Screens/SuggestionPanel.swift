import SwiftUI

/// What the add field offers while it has focus: the staples and past purchases before anything is typed, matches
/// after. The best match sits at the bottom, next to the field and the thumb. It is as tall as its rows, up to
/// `maxHeight`, so the list stays in sight above it.
struct SuggestionPanel: View {
    let model: ListModel
    @Binding var text: String
    let maxHeight: CGFloat

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        let suggestions = model.suggestions(for: text)
        ScrollView {
            VStack(spacing: 0) {
                ForEach(suggestions.reversed()) { suggestion in
                    SuggestionRow(suggestion: suggestion, aisle: aisle(of: suggestion)) {
                        model.pick(suggestion, typed: text)
                        text = ""
                    }
                    .contextMenu {
                        if suggestion.status == .remembered {
                            Button(role: .destructive) { model.forget(suggestion) } label: { Label("Forget", systemImage: "minus.circle") }
                        }
                    }
                    Divider().padding(.leading, 52)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.never)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(contentHeight, maxHeight))
        .background(.bar)
        .feedback(self)
    }

    private func aisle(of suggestion: Suggestion) -> Category? {
        guard model.list.grouping == .category, suggestion.status != .typed else { return nil }
        return Categorizer.place(suggestion.key, answers: model.snapshot.answers).category
    }
}

private struct SuggestionRow: View {
    let suggestion: Suggestion
    let aisle: Category?
    let pick: () -> Void

    var body: some View {
        Button(action: pick) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(suggestion.status == .onList ? Color.secondary : Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.status == .typed ? "Add “\(suggestion.name)”" : suggestion.name)
                        .foregroundStyle(.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if !suggestion.quantity.isEmpty {
                    Text(suggestion.quantity)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch suggestion.status {
        case .typed, .catalog, .remembered: "plus.circle"
        case .onList: "checkmark.circle"
        case .checked: "arrow.uturn.backward.circle"
        }
    }

    private var detail: String? {
        switch suggestion.status {
        case .onList: "On the list"
        case .checked: "Checked"
        case .typed: nil
        case .catalog, .remembered: aisle?.title
        }
    }
}
