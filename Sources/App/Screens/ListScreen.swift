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
                if isAdding { SuggestionPanel(model: model, text: $text, maxHeight: height * 0.4) }
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
                    ToolbarItem(placement: .primaryAction) {
                        Button(
                            model.hidesChecked ? "Show Checked" : "Hide Checked",
                            systemImage: model.hidesChecked ? "eye.slash" : "eye",
                            action: model.toggleHidingChecked
                        )
                    }
                    ToolbarItem(placement: clearPlacement) {
                        Button("Clear \(model.checkedCount)", action: model.clearChecked)
                            .accessibilityLabel("Clear \(model.checkedCount) checked \(model.checkedCount == 1 ? "item" : "items")")
                    }
                }
            }
        }
        .sheet(item: $editing) { id in ItemEditor(model: model, id: id) }
        .sheet(isPresented: $managingLists) { ListsEditor() }
        .sensoryFeedback(.selection, trigger: model.checkedCount)
        .onChange(of: model.listID) { text = "" }
        .feedback(self)
    }

    /// Two controls on one side push the title off center, so it would jump on the first check.
    private var clearPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }

    private var list: some View {
        ScrollViewReader { scroller in
            List {
                ForEach(model.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            ItemRowView(row: row, aisles: model.list.aisles, model: model) { editing = row.id }
                        }
                    } header: {
                        header(of: section.id)
                    }
                }
            }
            .listStyle(.plain)
            .onScrollPhaseChange { _, phase in
                if phase != .idle { model.touch() }
            }
            .onChange(of: model.added) { _, added in
                guard let last = added.last else { return }
                withAnimation(.snappy) { scroller.scrollTo(last, anchor: .center) }
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

    @ViewBuilder
    private func header(of section: SectionID) -> some View {
        switch section {
        case let .aisle(category):
            Label(category.title, systemImage: category.symbol)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(category.title)
                .accessibilityAddTraits(.isHeader)
        case .plain: EmptyView()
        }
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
