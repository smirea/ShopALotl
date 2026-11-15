import Testing
@testable import App

@Suite struct EntryParserTests {
    private func parsed(_ text: String) -> [String] {
        EntryParser.entries(in: text).map { [$0.name, $0.quantity, $0.note].joined(separator: "|") }
    }

    @Test func aPlainNameIsOneEntryWithACapital() {
        #expect(parsed("milk") == ["Milk||"])
        #expect(parsed("  Greek yogurt ") == ["Greek yogurt||"])
        #expect(parsed("iPhone cable") == ["iPhone cable||"])
    }

    @Test func commasSemicolonsAndLinesSplitEntries() {
        #expect(parsed("milk, eggs;bread\nbutter") == ["Milk||", "Eggs||", "Bread||", "Butter||"])
        #expect(parsed("milk,, ,") == ["Milk||"])
    }

    @Test func aLeadingNumberIsTheQuantityAndKeepsItsUnit() {
        #expect(parsed("2 milk") == ["Milk|2|"])
        #expect(parsed("2x milk") == ["Milk|2|"])
        #expect(parsed("500 g flour") == ["Flour|500 g|"])
        #expect(parsed("1.5 kg potatoes") == ["Potatoes|1.5 kg|"])
        #expect(parsed("2 cans chickpeas") == ["Chickpeas|2 cans|"])
    }

    @Test func aTrailingMultiplierIsTheQuantity() {
        #expect(parsed("eggs x12") == ["Eggs|12|"])
        #expect(parsed("Eggs ×12") == ["Eggs|12|"])
    }

    @Test func aNumberThatBelongsToTheNameStaysInIt() {
        #expect(parsed("2% milk") == ["2% milk||"])
        #expect(parsed("7up") == ["7up||"])
        #expect(parsed("vitamin b12") == ["Vitamin b12||"])
    }

    @Test func trailingParenthesesAreTheNoteAndMayHoldCommas() {
        #expect(parsed("tahini (the good one)") == ["Tahini||the good one"])
        #expect(parsed("3 limes (ripe, not hard), mint") == ["Limes|3|ripe, not hard", "Mint||"])
    }

    @Test func textWithoutAnyLetterOrDigitIsNothing() {
        #expect(parsed("") == [])
        #expect(parsed(" , ; ") == [])
        #expect(parsed("2") == ["2||"])
    }

    @Test func theKeyComesFromTheNameWithoutQuantityOrNote() {
        #expect(EntryParser.entries(in: "2 Crème fraîche (full fat)").map(\.key.text) == ["creme fraiche"])
    }
}
