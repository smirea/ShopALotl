import SwiftUI
import UIKit
import WidgetKit

@main
struct ShopALotlWidgets: WidgetBundle {
    var body: some Widget {
        ListWidget()
    }
}

struct ListWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppGroup.widgetKind, provider: ListProvider()) { entry in
            ListWidgetView(entry: entry)
        }
        .configurationDisplayName("List")
        .description("Check items off the open list.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ListEntry: TimelineEntry {
    let date: Date
    let rows: [Item]
    /// How many rows the widget has room for. The view splits its height between exactly this many slots.
    var capacity = 1
}

struct ListProvider: TimelineProvider {
    func placeholder(in context: Context) -> ListEntry {
        ListEntry(date: .now, rows: Self.sample, capacity: Self.capacity(in: context))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ListEntry) -> Void) {
        let isPreview = context.isPreview
        let capacity = Self.capacity(in: context)
        Task { @MainActor in
            var entry = WidgetStore.shared.entry()
            if isPreview && entry.rows.isEmpty { entry = ListEntry(date: .now, rows: Self.sample) }
            entry.capacity = capacity
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ListEntry>) -> Void) {
        let capacity = Self.capacity(in: context)
        Task { @MainActor in
            await WidgetStore.shared.syncIfStale()
            let now = Date.now
            var entry = WidgetStore.shared.entry(at: now)
            entry.capacity = capacity
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(30 * 60))))
        }
    }

    /// Rows of at least `minimumRowHeight` at the owner's text size inside the standard content margins.
    private static func capacity(in context: Context) -> Int {
        let height = context.displaySize.height - 2 * contentMargin
        return max(1, Int(height / UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: minimumRowHeight)))
    }

    private static let minimumRowHeight: CGFloat = 22
    private static let contentMargin: CGFloat = 16

    private static let sample: [Item] = ["Bananas", "Bread", "Eggs", "Milk", "Coffee", "Paper towels"].map { name in
        Item(id: ItemID(listID: ShoppingList.main.id, key: NameKey(name)!), name: name, addedAt: .now)
    }
}

struct ListWidgetView: View {
    let entry: ListEntry

    @Environment(\.widgetFamily) private var family
    @ScaledMetric(relativeTo: .subheadline) private var buttonSize: CGFloat = 22

    /// The open-app button sits on the last row instead of taking a row of its own. The large widget is tall enough
    /// that a tap on its background does the same.
    private var showsOpenButton: Bool { family != .systemLarge }

    var body: some View {
        let shown = Array(entry.rows.prefix(entry.capacity))
        // Every slot takes an equal share of the height, so the last row sits on the bottom edge under the button.
        VStack(alignment: .leading, spacing: 0) {
            ForEach(shown) { item in
                let underButton = showsOpenButton && shown.count == entry.capacity && item.id == shown.last?.id
                ItemRow(item: item, trailingInset: underButton ? buttonSize + 4 : 0)
                    .frame(maxHeight: .infinity)
            }
            ForEach(shown.count..<entry.capacity, id: \.self) { _ in
                Color.clear.frame(maxHeight: .infinity)
            }
        }
        .overlay {
            if entry.rows.isEmpty {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 64, maxHeight: 64)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsOpenButton {
                Link(destination: URL(string: "shopalotl://")!) {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: buttonSize * 0.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.brand, in: .circle)
                        .widgetAccentable()
                }
                .accessibilityLabel("Open ShopALotl")
            }
        }
        .font(.subheadline)
        .containerBackground(.background, for: .widget)
    }
}

/// One item, the whole row a check target, as in the app. A toggle rather than a button: WidgetKit flips its state the
/// moment it is tapped, so the check shows before the intent has written anything.
struct ItemRow: View {
    let item: Item
    let trailingInset: CGFloat

    var body: some View {
        let isChecked = item.state == .checked
        Toggle(isOn: isChecked, intent: CheckItemIntent(item.id, checked: !isChecked)) {
            Text(item.name)
        }
        .toggleStyle(ItemToggleStyle(quantity: item.quantity, trailingInset: trailingInset))
    }
}

struct ItemToggleStyle: ToggleStyle {
    let quantity: String
    let trailingInset: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let isChecked = configuration.isOn
        // Only draws: the Toggle itself takes the tap.
        return HStack(spacing: 6) {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isChecked ? Color.brand : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .widgetAccentable()
            configuration.label
                .strikethrough(isChecked)
                .foregroundStyle(isChecked ? .secondary : .primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if !quantity.isEmpty {
                Text(quantity)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .padding(.trailing, trailingInset)
        .frame(maxHeight: .infinity)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

extension Color {
    /// The app's accent. A widget extension does not pick up the catalog's global accent as `Color.accentColor`.
    static let brand = Color("AccentColor")
}
