import SwiftUI

/// The app is this screen: one list, its add bar, and the switcher behind its title.
struct ListScreen: View {
    let model: ListModel

    @Environment(AppModel.self) private var app
    @Observe(ShoppingList.all) private var lists
    @Observe(ShoppingList.neededCounts) private var neededCounts
    @State private var text = ""
    @FocusState private var isAdding: Bool
    @State private var editing: ItemID?
    @State private var managingLists = false
    @State private var height: CGFloat = 0

    var body: some View {
        let suggestions = isAdding ? model.suggestions(for: text) : []
        NavigationStack {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Group {
                        if model.isEmpty { emptyState } else { list }
                    }
                    .accessibilityHidden(isAdding)
                    if isAdding { closer }
                    if let undoable = model.undoable, !isAdding { UndoToast(undoable: undoable, undo: model.undo) }
                }
                if !suggestions.isEmpty {
                    SuggestionPanel(model: model, suggestions: suggestions, text: $text, maxHeight: height * 0.4)
                }
                AddBar(model: model, text: $text, isFocused: $isAdding)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .navigationTitle(model.list.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbarTitleMenu {
                Picker("List", selection: Binding(get: { model.listID }, set: app.open)) {
                    ForEach(lists) { list in
                        Text(neededCounts[list.id].map { "\(list.name) (\($0))" } ?? list.name).tag(list.id)
                    }
                }
                Button { managingLists = true } label: { Label("Lists…", systemImage: "list.bullet") }
            }
            .toolbar {
                if model.checkedCount > 0 {
                    ToolbarItem(placement: clearPlacement) {
                        Button("Clear \(model.checkedCount)", action: model.clearChecked)
                            .accessibilityLabel("Clear \(model.checkedCount) checked \(model.checkedCount == 1 ? "item" : "items")")
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if model.checkedCount > 0 {
                        Button(
                            model.hidesChecked ? "Show Checked" : "Hide Checked",
                            systemImage: model.hidesChecked ? "eye.slash" : "eye",
                            action: model.toggleHidingChecked
                        )
                    }
                    Button(
                        model.list.grouping == .category ? "Hide Categories" : "Show Categories",
                        systemImage: model.list.grouping == .category ? "list.bullet.indent" : "list.bullet",
                        action: model.toggleGrouping
                    )
                }
            }
        }
        .sheet(item: $editing) { id in ItemEditor(model: model, id: id) }
        .sheet(isPresented: $managingLists) { ListsEditor() }
        .sensoryFeedback(.selection, trigger: model.checkedCount)
        .onChange(of: model.listID) { text = "" }
        .feedback(self)
    }

    /// Keeping Clear on the leading side leaves the trailing view toggles compact and balances the title.
    private var clearPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }

    private var list: some View {
        let rows = Layout.displayRows(from: model.sections)
        return ScrollViewReader { scroller in
            List {
                ForEach(rows) { entry in
                    switch entry {
                    case let .header(category):
                        aisleHeader(for: category, isFirst: entry.id == rows.first?.id)
                    case let .item(row, inlineCategory, showsDividerAbove):
                        ItemRowView(row: row, aisles: model.list.aisles, model: model, inlineCategory: inlineCategory) {
                            editing = row.id
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: showsDividerAbove ? 6 : 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(showsDividerAbove ? topDividerBackground : nil)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 1)
            .onScrollPhaseChange { _, phase in
                if phase != .idle { model.touch() }
            }
            .onChange(of: model.landed) { _, landed in
                guard let last = landed?.rows.last else { return }
                withAnimation(.snappy) { scroller.scrollTo(DisplayRow.ID.item(last), anchor: .center) }
            }
        }
    }

    /// The list stays in sight while adding, and a tap on it closes the keyboard and the suggestions.
    private var closer: some View {
        Button { isAdding = false } label: {
            Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private func aisleHeader(for category: Category, isFirst: Bool) -> some View {
        ZStack {
            HStack(spacing: 8) {
                headerLine
                HStack(spacing: 5) {
                    Image(systemName: category.symbol)
                    Text(category.title)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(1)
                headerLine
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.title)
        .accessibilityAddTraits(.isHeader)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: isFirst ? 2 : 10, leading: 0, bottom: 4, trailing: 0))
    }

    private var topDividerBackground: some View {
        VStack(spacing: 0) {
            headerLine
                .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private var headerLine: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .accessibilityHidden(true)
            Text("Nothing on the list")
                .font(.title2.bold())
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ItemID: Identifiable {
    var id: String { text }
}

private struct UndoToast: View {
    let undoable: ListModel.Undoable
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(undoable.message)
                .lineLimit(1)
            Button("Undo", action: undo)
                .font(.body.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .padding(.bottom, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .id(undoable.id)
    }
}
