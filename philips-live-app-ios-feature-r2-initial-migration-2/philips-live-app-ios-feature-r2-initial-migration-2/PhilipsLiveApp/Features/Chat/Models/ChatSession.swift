import Foundation

/// The app-wide chat session: the conversation, its connection and attachment tray, and the agent and screen state
/// shown around them.
struct ChatSession: Equatable {
    var conversation = ChatConversation()
    var connection = ChatConnection()
    var tray = AttachmentTray()
    var isEndingChat = false
    var didClearFail = false
    var isAgentTyping = false
    var unreadCount = 0
    var isScreenActive = false
}
