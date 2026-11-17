import SwiftUI

/// Pushes an account page onto home's stack, unless it's already the page on top: a quick
/// double tap would otherwise push the same page twice. Home provides it; account pages use
/// it instead of `NavigationLink(value:)`, which appends on every tap.
struct ShowAccountPageAction {
    let push: (AccountPage) -> Void

    func callAsFunction(_ page: AccountPage) {
        push(page)
    }
}

extension EnvironmentValues {
    @Entry var showAccountPage = ShowAccountPageAction { _ in }
}
