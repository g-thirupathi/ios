import Foundation

/// The chat's messages and where the conversation stands: active, ended, or restarted below an ended one.
struct ChatConversation: Equatable {
    var phase: ChatPhase = .idle
    var messages: [ChatMessage] = []
    var oldMessages: [ChatMessage] = []
    var closedAt: Date?
    var previousClosedAt: Date?
    var didRestartAfterEnd = false
    var hasStartedNewChat = false

    var isChatEnded: Bool {
        phase == .ended
    }

    /// Whether this attempt to send an own message is still waiting for the SDK to confirm it. A later attempt at
    /// the same message is not this one.
    func isAwaitingDelivery(_ message: ChatMessage) -> Bool {
        guard let localId = message.localId else { return false }
        return messages.contains { candidate in
            guard candidate.localId == localId, candidate.sendAttempt == message.sendAttempt else { return false }
            return candidate.state == .sending
        }
    }

    var isRestartedChat: Bool {
        didRestartAfterEnd && previousClosedAt != nil
    }

    var hasRestartedChatStarted: Bool {
        isRestartedChat && (hasStartedNewChat || !messages.isEmpty)
    }
}
