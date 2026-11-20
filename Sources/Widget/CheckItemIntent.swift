import AppIntents

/// Checks or unchecks one item. Each row bakes in the state a tap leads to, so a tap on a row drawn from an older
/// timeline still does what the row showed, and a repeated tap changes nothing more.
struct CheckItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Item"
    static let isDiscoverable = false

    @Parameter(title: "Item") var item: String
    @Parameter(title: "Checked") var checked: Bool

    init() {}

    init(_ id: ItemID, checked: Bool) {
        item = id.text
        self.checked = checked
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = ItemID(text: item) { WidgetStore.shared.setChecked(id, checked) }
        return .result()
    }
}
