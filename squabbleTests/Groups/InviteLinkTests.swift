import Foundation
import Testing
@testable import squabble

struct InviteLinkTests {
    @Test func roundTripsACode() throws {
        let url = try #require(InviteLink.url(code: "Ab3_-xYz12345678"))
        #expect(url.absoluteString == "https://squabble-club.web.app/join/Ab3_-xYz12345678")
        #expect(InviteLink.code(from: url) == "Ab3_-xYz12345678")
    }

    @Test func stillOpensLinksWithTheFormerAddress() throws {
        let url = try #require(URL(string: "https://squabble-9c1df.web.app/join/Ab3_-xYz12345678"))
        #expect(InviteLink.code(from: url) == "Ab3_-xYz12345678")
    }

    @Test func showsTheAddressAndTheEndOfTheCode() {
        #expect(InviteLink.displayText(code: "Ab3_-xYz12345678") == "https://squabble-club.web.app/…5678")
        #expect(InviteLink.displayText(code: "short") == nil)
    }

    @Test(arguments: [
        "http://squabble-club.web.app/join/Ab3_xYz12345678",
        "https://example.com/join/Ab3_xYz12345678",
        "https://squabble-club.web.app/joins/Ab3_xYz12345678",
        "https://squabble-club.web.app/join/short",
        "https://squabble-club.web.app/join/Ab3_xYz12345678/extra",
        "https://squabble-club.web.app/join/bad%20code%20here",
    ])
    func ignoresAnythingElse(_ link: String) throws {
        #expect(InviteLink.code(from: try #require(URL(string: link))) == nil)
    }

    @MainActor @Test func inboxKeepsOnlyInviteLinks() throws {
        let inbox = InviteInbox()
        #expect(!inbox.receive(try #require(URL(string: "https://example.com/x"))))
        #expect(inbox.pending == nil)
        #expect(inbox.receive(try #require(URL(string: "https://squabble-club.web.app/join/Ab3_xYz12345678"))))
        #expect(inbox.pending?.code == "Ab3_xYz12345678")
    }

    @Test func qrMatrixHasFindersInThreeCorners() throws {
        let matrix = try #require(QRMatrix("https://squabble-club.web.app/join/Ab3_xYz12345678"))
        #expect(matrix.size >= 21 && matrix.size % 2 == 1)
        for (x, y) in [(0, 0), (matrix.size - 1, 0), (0, matrix.size - 1)] {
            #expect(matrix.isDark(x: x, y: y))
            #expect(matrix.isFinder(x: x, y: y))
        }
        // The finder's white ring, then its dark centre.
        #expect(!matrix.isDark(x: 1, y: 1))
        #expect(matrix.isDark(x: 3, y: 3))
        #expect(!matrix.isFinder(x: matrix.size - 1, y: matrix.size - 1))
    }

    @Test func groupReadsTheServersInviteCodeButNeverWritesIt() throws {
        let data: [String: Any] = ["name": "Trip", "currency": "EUR", "createdBy": "pal", "memberIds": ["pal"], "inviteCode": "Ab3_xYz12345678"]
        let group = try SquabbleGroup(id: "g1", firestoreData: data)
        #expect(group.inviteCode == "Ab3_xYz12345678")
        #expect(group.firestoreData["inviteCode"] == nil)
    }
}
