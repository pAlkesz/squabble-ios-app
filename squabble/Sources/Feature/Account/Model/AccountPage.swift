/// The account screens, pushed on home's navigation stack: the account itself, then its
/// editing pages.
enum AccountPage: Hashable {
    case account
    case displayName
    case paymentDetails
    case homeCurrency
}
