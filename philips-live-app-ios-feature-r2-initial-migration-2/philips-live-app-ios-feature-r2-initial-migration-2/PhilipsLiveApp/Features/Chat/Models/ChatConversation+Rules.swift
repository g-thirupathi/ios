import Foundation

extension ChatConversation {
    /// The conversation is over for the user: it ended, or it restarted and nothing new was sent yet.
    var isConversationClosed: Bool {
        isChatEnded || (isRestartedChat && !hasRestartedChatStarted)
    }

    /// A failed own message with content can be retried until the chat ends.
    func canResend(_ message: ChatMessage) -> Bool {
        (!message.text.isEmpty || !message.attachments.isEmpty) && !isChatEnded && retryableIndex(of: message) != nil
    }

    /// The failed own message that a retry of `message` sends again. Only the current conversation's messages are
    /// retried: an earlier conversation stays as it was when it closed. Attachments are sent again from their local
    /// files, so a message whose files are gone, such as one saved by R1, is not retried.
    func retryableIndex(of message: ChatMessage) -> Int? {
        messages.firstIndex { candidate in
            guard candidate.state == .failed, candidate.isFromUser, candidate.kind == .message,
                  candidate.attachments.allSatisfy({ $0.localFileUri != nil })
            else { return false }
            if let localId = message.localId {
                return candidate.localId == localId
            }
            if let id = message.id {
                return candidate.id == id
            }
            return candidate.localId == nil && candidate.id == nil && candidate.text == message.text
                && candidate.hasSameAttachments(as: message)
        }
    }

    /// The latest agent quick replies, until the user answers them or the conversation closes.
    var openQuickReply: OpenQuickReply? {
        guard !isConversationClosed,
              let index = messages.lastIndex(where: { $0.kind == .quickReply && !$0.options.isEmpty })
        else { return nil }
        let quickReply = messages[index]
        guard !messages[(index + 1)...].contains(where: { $0.kind == .message && $0.isFromUser }) else { return nil }
        let key = [
            previousClosedAt?.epochMilliseconds ?? "current",
            String(index),
            quickReply.timestamp?.epochMilliseconds ?? "",
            quickReply.text,
            quickReply.options.map { $0.payload.isEmpty ? $0.text : $0.payload }.joined(separator: "|"),
        ].joined(separator: "-")
        return OpenQuickReply(key: key, options: quickReply.options)
    }
}
