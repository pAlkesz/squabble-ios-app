/// Everything pushed on home's navigation stack: a squabble, or the account and its pages.
enum HomeRoute: Hashable {
    case squabble(id: String)
    case account(AccountPage)
}
