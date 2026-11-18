import Foundation
import OSLog

protocol DeliverTextMessageUseCase {
    /// Hands an already shown message to the chat once; `restart` starts a new conversation for it first. When the
    /// message is the user's retry of `failed`, the chat is asked first whether `failed` arrived after all.
    func execute(_ message: ChatMessage, restart: Bool, replacing failed: ChatMessage?) async
}

/// Each text is handed to the chat once, and is never sent again unless the user taps retry.
struct DefaultDeliverTextMessageUseCase: DeliverTextMessageUseCase {
    private let chat: ChatRepository
    private let restart: RestartChatUseCase
    private let waitForTransport: WaitForTransportUseCase
    private let watchDelivery: WatchDeliveryUseCase
    private let verifyDelivered: VerifyMessageDeliveredUseCase
    private let logger = Logger(category: "DeliverTextMessageUseCase")

    init(
        chat: ChatRepository,
        restart: RestartChatUseCase,
        waitForTransport: WaitForTransportUseCase,
        watchDelivery: WatchDeliveryUseCase,
        verifyDelivered: VerifyMessageDeliveredUseCase
    ) {
        self.chat = chat
        self.restart = restart
        self.waitForTransport = waitForTransport
        self.watchDelivery = watchDelivery
        self.verifyDelivered = verifyDelivered
    }

    func execute(_ message: ChatMessage, restart: Bool, replacing failed: ChatMessage?) async {
        guard let localId = message.localId, chat.session.conversation.isAwaitingDelivery(message) else { return }
        guard chat.session.connection.isNetworkAvailable else {
            chat.update { $0.conversation.markNotSent(message) }
            return
        }
        do {
            if restart || !chat.session.connection.isConfigured {
                try await self.restart.execute()
            }
            if !chat.isConnected, await !waitForTransport.execute(timeout: ChatTimeout.reconnectGrace) {
                throw ChatError.notConnected
            }
            if let failed, await verifyDelivered.execute(failed: failed, retried: message) {
                return
            }
            guard chat.session.conversation.isAwaitingDelivery(message) else { return }
            guard !chat.session.conversation.isChatEnded else {
                chat.update { $0.conversation.markNotSent(message) }
                return
            }
            try await chat.send(message.text, localId: localId)
            watchDelivery.execute(message)
        } catch {
            logger.error("Send message failed: \(error)")
            chat.update { $0.conversation.markNotSent(message) }
        }
    }
}
