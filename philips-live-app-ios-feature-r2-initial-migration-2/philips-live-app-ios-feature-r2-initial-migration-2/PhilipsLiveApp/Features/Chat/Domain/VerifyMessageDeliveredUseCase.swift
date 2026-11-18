import OSLog

protocol VerifyMessageDeliveredUseCase {
    /// Whether the chat has `failed` after all, a message that no confirmation arrived for and that the user sends
    /// again as `retried`. If so, `retried` takes the chat's copy and is not sent a second time.
    func execute(failed: ChatMessage, retried: ChatMessage) async -> Bool
}

/// A message that never left the phone has nothing to find. Unsure counts as not delivered: a second copy can be seen
/// and ignored, but a message that was lost cannot be recovered.
struct DefaultVerifyMessageDeliveredUseCase: VerifyMessageDeliveredUseCase {
    private let chat: ChatRepository
    private let logger = Logger(category: "VerifyMessageDeliveredUseCase")

    init(chat: ChatRepository) {
        self.chat = chat
    }

    func execute(failed: ChatMessage, retried: ChatMessage) async -> Bool {
        guard !failed.isUnsent else { return false }
        let recent: [ChatMessage]
        do {
            recent = try await chat.recentMessages()
        } catch {
            logger.error("Could not check whether the message arrived: \(error)")
            return false
        }
        let conversation = chat.session.conversation
        let knownIds = Set((conversation.messages + conversation.oldMessages).compactMap(\.id))
        let delivered = recent.first { candidate in
            let isKnown = candidate.id.map(knownIds.contains) ?? false
            return candidate.isFromUser && candidate.state == .sent && candidate.isSameDelivery(as: failed)
                && (candidate.id == failed.id || !isKnown)
        }
        guard let delivered else { return false }
        var isMarked = false
        chat.update { isMarked = $0.conversation.markDelivered(retried, as: delivered) }
        return isMarked
    }
}
