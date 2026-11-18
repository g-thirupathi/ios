import Foundation

extension ChatSession {
    var banner: ChatBanner? {
        if !connection.hasConnectivity {
            return .offline
        }
        return connection.isUnavailable ? .unavailable : nil
    }

    var canShowChatSurface: Bool {
        connection.isConfigured || connection.isReadOnly || conversation.isChatEnded
            || !conversation.messages.isEmpty || !conversation.oldMessages.isEmpty
    }
}
