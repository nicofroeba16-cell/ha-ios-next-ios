import Foundation
import Network

final class NetworkReachability: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "de.nicofroeba16.iosnext.network-path")

    func statuses() -> AsyncStream<Bool> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { [monitor] _ in
                monitor.cancel()
            }
            monitor.start(queue: queue)
        }
    }
}
