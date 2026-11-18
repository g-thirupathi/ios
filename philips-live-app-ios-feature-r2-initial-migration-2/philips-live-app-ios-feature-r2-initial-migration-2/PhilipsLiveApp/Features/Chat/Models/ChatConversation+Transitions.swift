import Foundation

extension ChatConversation {
    /// Opening the chat after it ended starts a new conversation below the old one.
    mutating func resumeAfterEnd() {
        previousClosedAt = closedAt
        moveMessagesToOldMessages()
        didRestartAfterEnd = true
        hasStartedNewChat = false
        phase = .active
        closedAt = nil
    }

    /// Sending into a closed chat starts a new conversation with this message. A conversation that already closed
    /// keeps the time it closed at.
    mutating func startNewChat(at date: Date) {
        previousClosedAt = closedAt ?? previousClosedAt ?? date
        moveMessagesToOldMessages()
        didRestartAfterEnd = true
        hasStartedNewChat = true
        phase = .active
        closedAt = nil
    }

    mutating func markNewChatStartedIfNeeded() {
        guard didRestartAfterEnd, !hasStartedNewChat else { return }
        hasStartedNewChat = true
        phase = .active
        closedAt = nil
    }

    mutating func activate() {
        phase = .active
    }

    /// Ended by the user or as read-only: the conversation stays where it is.
    mutating func end(at date: Date) {
        phase = .ended
        closedAt = date
    }

    /// The chat's session turned read-only. A conversation that is already closed keeps the time it closed at, as the
    /// session turns read-only again on every reconnect.
    mutating func markClosedIfOpen(at date: Date) {
        guard !isConversationClosed else { return }
        end(at: date)
    }

    /// Ended by the chat: a first conversation moves to the earlier ones.
    mutating func applyChatEnded(at date: Date) {
        if !messages.isEmpty, !didRestartAfterEnd {
            moveMessagesToOldMessages()
        }
        end(at: date)
    }

    mutating func updateMessage(id: String, state: DeliveryState, timestamp: Date?) {
        messages = messages.updatingState(id: id, state: state, timestamp: timestamp)
        oldMessages = oldMessages.updatingState(id: id, state: state, timestamp: timestamp)
    }

    mutating func updateAttachment(id: String, downloadUrl: String) {
        messages = messages.updatingDownloadUrl(attachmentId: id, downloadUrl: downloadUrl)
        oldMessages = oldMessages.updatingDownloadUrl(attachmentId: id, downloadUrl: downloadUrl)
    }

    /// Returns whether the message was added to the current conversation. An ended chat shows `oldMessages` and then
    /// `messages`, which a chat ended by the user still holds, so a late message joins the list shown last.
    mutating func receive(_ message: ChatMessage) -> Bool {
        guard !oldMessages.containsSame(as: message) else { return false }
        if isChatEnded, !didRestartAfterEnd {
            if messages.isEmpty {
                oldMessages = oldMessages.merging(message)
            } else {
                messages = messages.merging(message)
            }
            return false
        }
        messages = messages.merging(message)
        return true
    }

    /// Fails own messages left in Sending (e.g. sent into a dead socket) so the user can retry them. With
    /// `onlyAccepted`, only those the SDK already inserted (they have an id); the others are still queued to be sent.
    mutating func failStuckSendingMessages(onlyAccepted: Bool) {
        Self.failStuckSending(in: &messages, onlyAccepted: onlyAccepted)
    }

    /// Earlier conversations are out of reach of a send in flight, so nothing else fails what is left in Sending.
    mutating func failStuckSendingOldMessages() {
        Self.failStuckSending(in: &oldMessages, onlyAccepted: false)
    }

    private static func failStuckSending(in messages: inout [ChatMessage], onlyAccepted: Bool) {
        for index in messages.indices
            where messages[index].kind == .message && messages[index].isFromUser
            && [.sending, .idle].contains(messages[index].state)
            && (!onlyAccepted || messages[index].id != nil)
        {
            messages[index].state = .failed
        }
    }

    /// Messages that leave the current conversation fail first if still sending: `markFailed` and `markNotSent` only
    /// look at the current conversation, so they would stay in Sending for good. A late confirmation still turns one
    /// back into sent.
    private mutating func moveMessagesToOldMessages() {
        failStuckSendingMessages(onlyAccepted: false)
        oldMessages += messages
        messages = []
    }

    /// A retried attachment message was uploaded again, so its attachments have new ids.
    mutating func replaceAttachments(localId: String, with attachments: [ChatAttachment]) {
        guard let index = messages.firstIndex(where: { $0.localId == localId }) else { return }
        messages[index].attachments = attachments
    }

    /// Shows what the user just sent at once; it stays `sending` until the SDK confirms or the send fails.
    mutating func appendLocalMessage(_ message: ChatMessage) {
        messages.append(message)
    }

    mutating func markFailed(_ message: ChatMessage) {
        failIfPending(message)
    }

    /// The chat has the message after all: the bubble takes the chat's copy, which is sent. Returns whether the
    /// bubble was still in the current conversation.
    mutating func markDelivered(_ message: ChatMessage, as delivered: ChatMessage) -> Bool {
        guard let localId = message.localId, let index = messages.firstIndex(where: { $0.localId == localId }) else {
            return false
        }
        messages[index] = delivered.keepingLocalId(of: messages[index])
        return true
    }

    /// The message failed before it reached the chat.
    mutating func markNotSent(_ message: ChatMessage) {
        if let index = failIfPending(message) {
            messages[index].isUnsent = true
        }
    }

    /// Fails this attempt to send the message while it is still sending or idle, and returns its index. A later
    /// attempt is left alone: a timer or send left over from the earlier one must not fail it.
    @discardableResult
    private mutating func failIfPending(_ message: ChatMessage) -> Int? {
        guard let localId = message.localId, let index = messages.firstIndex(where: { candidate in
            guard candidate.localId == localId, candidate.sendAttempt == message.sendAttempt else { return false }
            return [.sending, .idle].contains(candidate.state)
        }) else { return nil }
        messages[index].state = .failed
        return index
    }

    /// Flips a failed message back to sending and returns it, or nil when it is no longer failed, e.g. a second tap
    /// on retry. Messages saved before local ids existed get `newLocalId`. The retry is a new message for the chat, so
    /// the id of the failed attempt is dropped and the retry's echo replaces the bubble.
    mutating func markSendingAgain(_ message: ChatMessage, newLocalId: String) -> ChatMessage? {
        guard let index = retryableIndex(of: message) else { return nil }
        messages[index].state = .sending
        messages[index].sendAttempt += 1
        messages[index].id = nil
        messages[index].isUnsent = false
        messages[index].localId = messages[index].localId ?? newLocalId
        return messages[index]
    }
}
