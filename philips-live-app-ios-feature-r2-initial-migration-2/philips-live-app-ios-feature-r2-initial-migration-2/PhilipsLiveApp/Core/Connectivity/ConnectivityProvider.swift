import Foundation
import Network
import UIKit

protocol ConnectivityProvider {
    var isConnected: Bool { get }
    func updates() -> AsyncStream<Bool>
}

final class NWPathConnectivityProvider: ConnectivityProvider {
    private static let queueLabel = "PhilipsLiveApp.ConnectivityProvider"

    private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async { self?.publish(connected) }
        }
        monitor.start(queue: DispatchQueue(label: Self.queueLabel))
        // The path can change while the app is suspended, and the monitor may report it only some time after the app is
        // back. The provider lives as long as the app, so the observer is never removed.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.publish(self.monitor.currentPath.status == .satisfied)
            }
        }
    }

    deinit {
        monitor.cancel()
    }

    func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                DispatchQueue.main.async { self?.continuations[id] = nil }
            }
        }
    }

    private func publish(_ connected: Bool) {
        guard connected != isConnected else { return }
        isConnected = connected
        continuations.values.forEach { $0.yield(connected) }
    }
}
