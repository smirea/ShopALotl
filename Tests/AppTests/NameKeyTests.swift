import Testing
@testable import App

/// The rules are frozen: an item's id holds its key. A case that changes here orphans rows already synced.
@Suite struct NameKeyTests {
    @Test(arguments: [
        ("Milk", "milk"),
        ("  Oat   Milk ", "oat milk"),
        ("Crème Fraîche", "creme fraiche"),
        ("CREME-FRAICHE", "creme fraiche"),
        ("Half & Half", "half half"),
        ("M&M's", "m m s"),
        ("7-Up", "7 up"),
        ("2% milk", "2 milk"),
        ("Jalapeño (fresh)", "jalapeno fresh"),
        ("İstanbul simit", "istanbul simit"),
        ("ｆｕｌｌｗｉｄｔｈ", "fullwidth"),
        ("豆腐", "豆腐"),
        ("Müsli", "musli"),
        ("apples", "apples"),
    ])
    func aKeyIsTheNameInLowercaseWithoutAccentsOrPunctuationAndSingleSpaced(name: String, key: String) {
        #expect(NameKey(name)?.text == key)
    }

    @Test(arguments: ["", "   ", "—", "!!!", "🥑"])
    func aNameWithoutLettersOrDigitsHasNoKey(name: String) {
        #expect(NameKey(name) == nil)
    }

    @Test func anItemIDRoundTripsThroughItsText() {
        let id = ItemID(listID: "main", key: NameKey("Oat Milk")!)
        #expect(id.text == "main/oat milk")
        #expect(ItemID(text: id.text) == id)
        #expect(ItemID(text: "no-slash") == nil)
        #expect(ItemID(text: "main/") == nil)
    }
}
