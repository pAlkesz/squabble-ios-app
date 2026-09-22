import Foundation
import Testing
@testable import squabble

struct PaymentLinkTests {
    @Test(arguments: [
        (PaymentProvider.revolut, "pal", "pal"),
        (.revolut, "@pal", "pal"),
        (.revolut, "https://revolut.me/pal", "pal"),
        (.paypal, "https://www.paypal.com/paypalme/PalPapp/12", "PalPapp"),
        (.paypal, "paypal.me/palpapp", "palpapp"),
        (.wise, "wise.com/pay/me/palp12", "palp12"),
    ])
    func extractsUsername(provider: PaymentProvider, input: String, expected: String) throws {
        #expect(try PaymentLink(provider: provider, input: input).username == expected)
    }

    @Test func rebuildsTheLinkFromTheUsername() throws {
        let link = try PaymentLink(provider: .wise, input: "palp12")
        #expect(link.url == URL(string: "https://wise.com/pay/me/palp12"))
    }

    @Test func refusesLinksToOtherSites() {
        #expect(throws: PaymentLinkError.wrongProvider) {
            try PaymentLink(provider: .revolut, input: "https://evil.example/revolut.me/pal")
        }
        #expect(throws: PaymentLinkError.wrongProvider) {
            try PaymentLink(provider: .paypal, input: "revolut.me/pal")
        }
    }

    @Test(arguments: ["", "p", "pal?amount=1", "pal<script>", "https://revolut.me/"])
    func rejectsBadUsernames(input: String) {
        #expect(throws: PaymentLinkError.invalidUsername) {
            try PaymentLink(provider: .revolut, input: input)
        }
    }
}
