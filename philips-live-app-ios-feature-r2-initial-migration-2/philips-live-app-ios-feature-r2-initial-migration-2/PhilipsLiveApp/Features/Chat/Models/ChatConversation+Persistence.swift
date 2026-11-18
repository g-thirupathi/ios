import Foundation

extension ChatConversation {
    /// Restores the conversation saved before the last launch. Own messages still sending then can never be
    /// confirmed, so they fail; the current conversation's can be retried.
    init(restoring persisted: PersistedChat) {
        self.init(
            messages: persisted.messages,
            oldMessages: persisted.oldMessages,
            closedAt: persisted.closedAt,
            previousClosedAt: persisted.previousClosedAt,
            didRestartAfterEnd: persisted.previousClosedAt != nil
        )
        if persisted.closedAt != nil {
            phase = .ended
        } else if persisted.previousClosedAt != nil || !persisted.messages.isEmpty {
            phase = .active
        }
        failStuckSendingMessages(onlyAccepted: false)
        failStuckSendingOldMessages()
    }

    /// Replaces the empty conversation started while the saved one could not be read.
    mutating func restore(_ persisted: PersistedChat) {
        self = ChatConversation(restoring: persisted)
    }

    var persisted: PersistedChat {
        PersistedChat(
            messages: messages,
            oldMessages: oldMessages,
            closedAt: closedAt,
            previousClosedAt: previousClosedAt
        )
    }
}
