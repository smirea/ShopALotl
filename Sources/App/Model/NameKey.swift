import Foundation

/// What makes two typed names the same item: "Crème Fraîche", "creme  fraiche" and "CREME-FRAICHE" share a key.
///
/// The rules are frozen. An item's id holds its key, so a change here would orphan every row made before, and a web
/// client must produce the same text: lowercase, decompose (NFKD), drop combining marks, turn every run of anything
/// but letters and digits into one space, trim. `NameKeyTests` pins them.
struct NameKey: Hashable, Sendable, CustomStringConvertible {
    let text: String

    /// Nil when the name has no letter or digit.
    init?(_ name: String) {
        var words: [String] = []
        var word = String.UnicodeScalarView()
        for scalar in name.lowercased().decomposedStringWithCompatibilityMapping.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark:
                continue
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
                 .decimalNumber, .letterNumber, .otherNumber:
                word.append(scalar)
            default:
                if !word.isEmpty { words.append(String(word)) }
                word = .init()
            }
        }
        if !word.isEmpty { words.append(String(word)) }
        guard !words.isEmpty else { return nil }
        text = words.joined(separator: " ")
    }

    /// A key read back from a row, which `init(_:)` already normalized when it was written.
    init?(stored text: String) {
        guard !text.isEmpty else { return nil }
        self.text = text
    }

    var description: String { text }

    var words: [Substring] { text.split(separator: " ") }
}
