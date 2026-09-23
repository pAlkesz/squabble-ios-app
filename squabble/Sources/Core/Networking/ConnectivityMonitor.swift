nonisolated protocol ConnectivityMonitor: Sendable {
    /// Emits whether the device can currently reach the network, immediately and then on
    /// every change, until cancelled.
    func updates() -> AsyncStream<Bool>
}
