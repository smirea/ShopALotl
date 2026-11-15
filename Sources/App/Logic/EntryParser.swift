import Foundation

/// One thing the owner typed into the add field.
struct Entry: Equatable, Sendable {
    let key: NameKey
    var name: String
    /// Display text such as `2` or `500 g`, `""` when none was typed.
    var quantity = ""
    var note = ""
}

/// Turns typed text into entries. "2 milk, eggs x12, tahini (the good one)" is three of them.
enum EntryParser {
    private static let units: Set<String> = [
        "g", "kg", "oz", "lb", "lbs", "ml", "l", "cl", "dl", "gal", "qt", "pt", "cup", "cups", "tsp", "tbsp",
        "pack", "packs", "pk", "bottle", "bottles", "can", "cans", "box", "boxes", "bag", "bags", "jar", "jars",
        "bunch", "bunches", "dozen", "loaf", "loaves", "roll", "rolls", "carton", "cartons", "pcs", "piece", "pieces",
    ]

    static func entries(in text: String) -> [Entry] {
        segments(of: text).compactMap(entry)
    }

    /// Splits on commas, semicolons, and line breaks, except inside parentheses, where a note may hold them.
    private static func segments(of text: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var depth = 0
        for character in text {
            if character == "(" { depth += 1 }
            if character == ")" { depth = max(0, depth - 1) }
            if depth == 0, character == "," || character == ";" || character.isNewline {
                segments.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        return segments + [current]
    }

    private static func entry(_ segment: String) -> Entry? {
        var text = segment.trimmingCharacters(in: .whitespaces)
        var note = ""
        if text.hasSuffix(")"), let open = text.lastIndex(of: "("), open != text.startIndex {
            note = text[text.index(after: open)...].dropLast().trimmingCharacters(in: .whitespaces)
            text = text[..<open].trimmingCharacters(in: .whitespaces)
        }
        var quantity = ""
        if let match = text.wholeMatch(of: /(.+?)\s*[x×]\s*(\d+)/.ignoresCase()) {
            (text, quantity) = (String(match.1), String(match.2))
        } else if let match = text.wholeMatch(of: /(\d+(?:[.,]\d+)?)\s*[x×]?\s+(.+)/.ignoresCase()) {
            (quantity, text) = (String(match.1), String(match.2))
            if let space = text.firstIndex(of: " "), units.contains(text[..<space].lowercased()) {
                quantity += " \(text[..<space])"
                text = text[text.index(after: space)...].trimmingCharacters(in: .whitespaces)
            }
        }
        guard let key = NameKey(text) else { return nil }
        return Entry(key: key, name: displayName(text), quantity: quantity, note: note)
    }

    /// A name typed all in lowercase gets a capital, as a list reads better that way. Anything else is kept as typed.
    static func displayName(_ name: String) -> String {
        guard name == name.lowercased(), let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }
}
