import Foundation

protocol WaitForTransportUseCase {
    /// Waits while the network is up until the transport is connected, `timeout` passes or the task is cancelled.
    func execute(timeout: TimeInterval) async -> Bool
}

struct DefaultWaitForTransportUseCase: WaitForTransportUseCase {
    private static let pollInterval: Duration = .milliseconds(200)

    private let chat: ChatRepository
    private let now: () -> Date

    init(chat: ChatRepository, now: @escaping () -> Date = Date.init) {
        self.chat = chat
        self.now = now
    }

    func execute(timeout: TimeInterval) async -> Bool {
        let start = now()
        while chat.session.connection.isNetworkAvailable, !chat.isConnected, !Task.isCancelled,
              now().timeIntervalSince(start) < timeout
        {
            try? await Task.sleep(for: Self.pollInterval)
        }
        return chat.isConnected
    }
}
