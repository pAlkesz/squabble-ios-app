nonisolated protocol RatesRepository: Sendable {
    /// From the cache first, then every change; nil while there are none.
    func latestRates() -> AsyncThrowingStream<ExchangeRates?, Error>
}
