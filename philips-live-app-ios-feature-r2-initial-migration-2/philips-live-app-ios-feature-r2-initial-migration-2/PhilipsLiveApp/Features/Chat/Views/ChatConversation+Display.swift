import Foundation

extension ChatConversation {
    var showsChatEndedCard: Bool {
        isConversationClosed
    }

    /// The chat list. A closed chat ends with the ended banner alone; the "closed at" divider separates the earlier
    /// conversation only once a new one has started.
    var listItems: [ChatListItem] {
        if didRestartAfterEnd, let previousClosedAt {
            let earlier = oldMessages.map(ChatListItem.message)
            guard hasRestartedChatStarted else { return earlier }
            return earlier + [.closedDivider(previousClosedAt)] + messages.map(ChatListItem.message)
        }
        guard isChatEnded else { return messages.map(ChatListItem.message) }
        var seenIds = Set<String>()
        return (oldMessages + messages)
            .filter { message in message.id.map { seenIds.insert($0).inserted } ?? true }
            .map(ChatListItem.message)
    }
}
