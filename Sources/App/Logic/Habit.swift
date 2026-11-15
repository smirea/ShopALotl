import Foundation

/// How the owner buys one item, derived from when it was checked off.
struct Habit: Equatable, Sendable {
    let count: Int
    let last: Date?
    /// The usual time between purchases: the median gap. Nil before the second purchase.
    let interval: TimeInterval?

    init(bought: [Date]) {
        count = bought.count
        last = bought.last
        // Two checks within half a day are one shopping trip, not a rhythm.
        let gaps = zip(bought.dropFirst(), bought).map { $0.timeIntervalSince($1) }.filter { $0 > 12 * 3600 }.sorted()
        interval = gaps.isEmpty ? nil : gaps[gaps.count / 2]
    }

    /// How far through its usual interval the item is: 1 means due today. Nil without a rhythm.
    func dueness(at now: Date) -> Double? {
        guard let last, let interval else { return nil }
        return now.timeIntervalSince(last) / interval
    }

    /// Frequency and recency in one number: each purchase counts, and counts half as much every 45 days.
    static func frecency(bought: [Date], at now: Date) -> Double {
        bought.reduce(0) { $0 + pow(0.5, max(0, now.timeIntervalSince($1)) / (45 * 86_400)) }
    }
}
