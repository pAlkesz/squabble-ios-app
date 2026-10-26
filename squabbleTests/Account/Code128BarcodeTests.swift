import Testing
@testable import squabble

struct Code128BarcodeTests {
    @Test func encodesAHandleIntoBarsStartingAndEndingDark() throws {
        let modules = try #require(Code128Barcode.modules(for: "@palkesz"))
        #expect(modules.count > 60)
        #expect(modules.first == true)
        #expect(modules.last == true)
    }

    @Test func differentHandlesGiveDifferentBars() {
        #expect(Code128Barcode.modules(for: "@pal") != Code128Barcode.modules(for: "@bob"))
    }

    @Test func emptyTextHasNoBarcode() {
        #expect(Code128Barcode.modules(for: "") == nil)
    }
}
