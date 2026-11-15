import SwiftUI

/// The add field, pinned to the bottom edge in thumb reach, with the staples that are due above it.
struct AddBar: View {
    let model: ListModel
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 8) {
            if !isFocused.wrappedValue, !model.due.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(model.due) { suggestion in
                            Button {
                                model.pick(suggestion, typed: "")
                            } label: {
                                Label(suggestion.name, systemImage: "plus")
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.accentColor.opacity(0.14), in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel("Add \(suggestion.name)")
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .accessibilityLabel("Due staples")
            }
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                TextField("Add item", text: $text)
                    .focused(isFocused)
                    .submitLabel(.return)
                    .onSubmit(submit)
                    .accessibilityHint("Separate several items with commas")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.fill.tertiary, in: .rect(cornerRadius: 14))
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
        .feedback(self)
    }

    /// Return adds what was typed and keeps the keyboard up for the next item. Return on an empty field closes it.
    private func submit() {
        if model.add(text) {
            text = ""
            isFocused.wrappedValue = true
        }
    }
}
