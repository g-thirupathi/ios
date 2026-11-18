import Foundation

/// Applies what happens in the chat outside the app's own actions.
extension ChatSession {
    /// `newLocalId` identifies a quick reply created from the event.
    mutating func apply(_ event: ChatEvent, at date: Date, newLocalId: String) {
        switch event {
            case let .connectionState(isConfigured, connected, conversationClearEnabled, failure):
                applyConnectionEvent(
                    isConfigured: isConfigured,
                    connected: connected,
                    conversationClearEnabled: conversationClearEnabled,
                    failure: failure
                )
            case let .sdkNetworkAvailability(isAvailable):
                connection.applySdkNetworkAvailability(isAvailable)
            case .readOnly:
                connection.markReadOnly()
                conversation.markClosedIfOpen(at: date)
            case .chatEnded:
                isAgentTyping = false
                conversation.applyChatEnded(at: date)
            case let .conversationClearAnswered(isCleared):
                applyConversationClearAnswer(isCleared: isCleared, at: date)
            case let .messageUpdated(id, deliveryState, timestamp):
                conversation.updateMessage(id: id, state: deliveryState, timestamp: timestamp)
            case let .attachmentUpdated(id, pendingId, uploadState, downloadUrl):
                applyAttachmentUpdate(id: id, pendingId: pendingId, state: uploadState, downloadUrl: downloadUrl)
            case .agentTyping:
                isAgentTyping = true
            case let .messageInserted(message):
                receiveInserted(message, at: date)
            case let .quickReplyReceived(text, options, sender):
                isAgentTyping = false
                _ = conversation.receive(ChatMessage(
                    localId: newLocalId,
                    kind: .quickReply,
                    direction: .outbound,
                    text: text,
                    state: .sent,
                    timestamp: nil,
                    options: options,
                    sender: sender
                ))
        }
    }

    /// A lost transport stops the typing indicator; a lost configuration fails sends the SDK accepted but never sent.
    private mutating func applyConnectionEvent(
        isConfigured: Bool,
        connected: Bool,
        conversationClearEnabled: Bool,
        failure: ChatConnectionError?
    ) {
        connection.apply(
            isConfigured: isConfigured,
            connected: connected,
            conversationClearEnabled: conversationClearEnabled
        )
        if let failure, connection.isNetworkAvailable || failure == .unavailable {
            connection.fail(failure)
        }
        if !(isConfigured && connected) {
            isAgentTyping = false
        }
        if !isConfigured {
            conversation.failStuckSendingMessages(onlyAccepted: true)
        }
    }

    /// A cleared conversation ends the chat whenever the chat confirms it: after the user's request, a late answer
    /// or a clear done on another device. Only a refusal while the user's request runs is a failure to report.
    private mutating func applyConversationClearAnswer(isCleared: Bool, at date: Date) {
        if isCleared {
            isAgentTyping = false
            if conversation.isChatEnded {
                connection.markCleared()
            } else if !conversation.isConversationClosed {
                connection.markCleared()
                conversation.end(at: date)
            }
        } else if isEndingChat {
            didClearFail = true
        }
    }

    private mutating func applyAttachmentUpdate(
        id: String,
        pendingId: PendingAttachment.ID?,
        state uploadState: AttachmentUploadState,
        downloadUrl: String?
    ) {
        if tray.isSending {
            tray.updateItem(pendingId: pendingId, state: uploadState)
        }
        if let downloadUrl {
            conversation.updateAttachment(id: id, downloadUrl: downloadUrl)
        }
    }

    /// An agent message that arrives while the chat screen is closed counts as unread.
    private mutating func receiveInserted(_ message: ChatMessage, at date: Date) {
        isAgentTyping = false
        var message = message
        message.timestamp = message.timestamp ?? date
        guard conversation.receive(message), message.kind == .message, !message.isFromUser, !isScreenActive else {
            return
        }
        unreadCount += 1
    }
}
