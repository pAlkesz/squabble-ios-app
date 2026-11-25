import FactoryKit
import Observation

/// The latest exchange rates, kept live for as long as home is up and shared with the pages
/// pushed from it. Works offline with the last ones seen.
@Observable
final class RatesStore {
    /// Nil until there are any.
    private(set) var rates: ExchangeRates?

    private let repository: RatesRepository

    init(repository: RatesRepository = Container.shared.ratesRepository()) {
        self.repository = repository
    }

    func observe() async {
        do {
            for try await rates in repository.latestRates() {
                if let rates { self.rates = rates }
            }
        } catch {
            // Signing out kills the listener with a permission error; that's not a failure.
            guard !Task.isCancelled else { return }
            AppLog.error(error, "Rates listener failed")
        }
    }
}
