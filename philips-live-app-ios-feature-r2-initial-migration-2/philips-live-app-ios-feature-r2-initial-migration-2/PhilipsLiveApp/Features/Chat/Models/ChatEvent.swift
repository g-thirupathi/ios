import Foundation

enum ChatEvent {
    /// `failure`: the chat gave up connecting for a reason other than the network.
    case connectionState(
        isConfigured: Bool,
        connected: Bool,
        conversationClearEnabled: Bool,
        failure: ChatConnectionError? = nil
    )
    case sdkNetworkAvailability(Bool)
    case readOnly
    case messageInserted(ChatMessage)
    case messageUpdated(id: String, state: DeliveryState, timestamp: Date?)
    case quickReplyReceived(text: String, options: [QuickReplyOption], sender: ChatSender)
    case attachmentUpdated(
        id: String,
        pendingId: PendingAttachment.ID?,
        state: AttachmentUploadState,
        downloadUrl: String?
    )
    case agentTyping(durationMilliseconds: Int64?)
    case chatEnded
    /// The chat's answer to a request to clear the conversation.
    case conversationClearAnswered(isCleared: Bool)
}
