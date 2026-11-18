import Foundation
import OSLog

protocol WaitForChatConnectionUseCase {
    /// Waits up to a minute for the transport, or until the task is cancelled, restarting the chat whenever it is not
    /// configured. Returns at once when no chat is set up for the support country.
    func execute(restartingFirst: Bool) async -> Bool
}

struct DefaultWaitForChatConnectionUseCase: WaitForChatConnectionUseCase {
    private static let timeout: TimeInterval = 60
    private static let pollInterval: TimeInterval = 2

    private let chat: ChatRepository
    private let restart: RestartChatUseCase
    private let waitForTransport: WaitForTransportUseCase
    private let now: () -> Date
    private let logger = Logger(category: "WaitForChatConnectionUseCase")

    init(
        chat: ChatRepository,
        restart: RestartChatUseCase,
        waitForTransport: WaitForTransportUseCase,
        now: @escaping () -> Date = Date.init
    ) {
        self.chat = chat
        self.restart = restart
        self.waitForTransport = waitForTransport
        self.now = now
    }

    func execute(restartingFirst: Bool) async -> Bool {
        guard chat.session.connection.isNetworkAvailable else { return false }
        chat.update { $0.connection.showReconnecting() }
        var shouldRestart = restartingFirst || !chat.session.connection.isConfigured
        let start = now()
        repeat {
            if shouldRestart {
                do {
                    try await restart.execute()
                } catch ChatError.missingConfiguration, ChatError.unavailable {
                    return false
                } catch {
                    logger.error("Restart chat before uploading failed: \(error)")
                }
                shouldRestart = false
            }
            _ = await waitForTransport.execute(timeout: Self.pollInterval)
            if !chat.isConnected, !chat.session.connection.isConfigured {
                shouldRestart = true
            }
        } while chat.session.connection.isNetworkAvailable && !chat.isConnected && !Task.isCancelled
            && now().timeIntervalSince(start) < Self.timeout
        if chat.isConnected {
            chat.update { $0.connection.markConnected() }
        }
        return chat.isConnected
    }
}
