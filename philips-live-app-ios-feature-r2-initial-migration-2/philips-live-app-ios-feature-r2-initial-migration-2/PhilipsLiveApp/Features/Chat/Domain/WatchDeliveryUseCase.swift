protocol WatchDeliveryUseCase {
    /// Fails this attempt to send the message if the chat has not confirmed it in time. A confirmation that arrives
    /// later still turns it back into sent, and a retry made meanwhile is not affected.
    func execute(_ message: ChatMessage)
}

struct DefaultWatchDeliveryUseCase: WatchDeliveryUseCase {
    private static let timeout: Duration = .seconds(20)

    private let chat: ChatRepository

    init(chat: ChatRepository) {
        self.chat = chat
    }

    func execute(_ message: ChatMessage) {
        Task {
            try? await Task.sleep(for: Self.timeout)
            guard chat.session.conversation.isAwaitingDelivery(message) else { return }
            chat.update { $0.conversation.markFailed(message) }
        }
    }
}
