import SwiftUI

/// What the add field offers while it has focus: the staples and past purchases before anything is typed, matches
/// after. The best match sits at the bottom, next to the field and the thumb.
struct SuggestionPanel: View {
    let model: ListModel
    @Binding var text: String

    var body: some View {
        let suggestions = model.suggestions(for: text)
        ScrollView {
            LazyVStack(spacing: 0) {
                if suggestions.isEmpty {
                    Text(hint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(24)
                }
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
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.never)
        .background(.background)
        .feedback(self)
    }

    private var hint: String {
        let count = EntryParser.entries(in: text).count
        if count > 1 { return "Return adds \(count) items." }
        return "Type a name, or several separated by commas. What you buy often shows up here."
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
        case .checked: "Checked off. Tap to need it again."
        case .typed: nil
        case .catalog, .remembered: aisle?.title
        }
    }
}
