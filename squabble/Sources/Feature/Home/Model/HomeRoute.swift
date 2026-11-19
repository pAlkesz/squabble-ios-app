/// Everything pushed on home's navigation stack: the squabble list, a squabble and its info
/// page, or the account and its pages.
enum HomeRoute: Hashable {
    case squabbles
    case squabble(id: String)
    case squabbleInfo(id: String)
    case account(AccountPage)
}
