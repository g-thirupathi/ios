import Foundation

extension ChatSession {
    /// Sending into a closed or read-only chat starts a new conversation with this message.
    mutating func startNewChatAfterClosure(at date: Date) {
        conversation.startNewChat(at: date)
        connection.leaveReadOnly()
    }

    mutating func screenDidAppear() {
        unreadCount = 0
        isScreenActive = true
        connection.invalidateSession()
    }

    mutating func screenDidDisappear() {
        isScreenActive = false
    }

    mutating func applyNetworkChange(isConnected: Bool) {
        connection.applyNetworkChange(isConnected: isConnected, isScreenActive: isScreenActive)
    }

    mutating func hideAgentTyping() {
        isAgentTyping = false
    }

    mutating func beginEndingChat() {
        isEndingChat = true
        didClearFail = false
    }

    mutating func finishEndingChat() {
        isEndingChat = false
        didClearFail = false
    }

    /// Nothing was sent: the tray and text stay as they were, so the user can try again.
    mutating func failAttachmentSend(alert: AttachmentAlert, isConnectionLost: Bool) {
        if isConnectionLost {
            connection.markConnectionLost()
        }
        tray.failSend(alert: alert)
    }
}
