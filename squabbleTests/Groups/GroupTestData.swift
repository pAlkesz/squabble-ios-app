import Foundation
@testable import squabble

nonisolated enum GroupTestData {
    static func profile(_ uid: String, handle: String? = nil, name: String? = nil) -> UserProfile {
        UserProfile(
            id: uid,
            displayName: name ?? uid.capitalized,
            // Test handles are always valid.
            handle: try! Handle(validating: handle ?? uid),
            avatar: .persona(.bigSpender, .plum)
        )
    }

    static func revolut(_ username: String) -> PaymentMethod {
        PaymentMethod(id: "pm-\(username)", kind: .link(try! PaymentLink(provider: .revolut, input: username)))
    }
}
