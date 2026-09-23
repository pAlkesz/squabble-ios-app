import Foundation
import Network

nonisolated final class NetworkPathConnectivityMonitor: ConnectivityMonitor {
    func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "com.palkesz.squabble.connectivity"))
        }
    }
}
