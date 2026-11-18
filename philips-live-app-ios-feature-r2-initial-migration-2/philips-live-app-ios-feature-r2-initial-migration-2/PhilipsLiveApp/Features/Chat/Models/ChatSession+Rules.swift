import Foundation

extension ChatSession {
    /// "End chat" works while the chat is connected and its deployment allows clearing the conversation, until the
    /// conversation closes.
    func canEndChat(in country: SupportCountry) -> Bool {
        country.hasChatOptionsMenu && connection.isConversationClearEnabled && connection.isConfigured
            && connection.status == .connected && !isEndingChat && !conversation.isConversationClosed
    }
}
