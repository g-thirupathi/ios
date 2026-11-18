import Foundation

protocol PrepareAttachmentTransportUseCase {
    /// Gets the chat ready for an upload, restarting it for up to a minute if it is down. Uploading into a closed
    /// chat starts a new conversation first.
    func execute() async -> Bool
}

struct DefaultPrepareAttachmentTransportUseCase: PrepareAttachmentTransportUseCase {
    private let chat: ChatRepository
    private let waitForConnection: WaitForChatConnectionUseCase
    private let now: () -> Date

    init(
        chat: ChatRepository,
        waitForConnection: WaitForChatConnectionUseCase,
        now: @escaping () -> Date = Date.init
    ) {
        self.chat = chat
        self.waitForConnection = waitForConnection
        self.now = now
    }

    func execute() async -> Bool {
        if !chat.session.connection.isConfigured, await !waitForConnection.execute(restartingFirst: true) {
            return false
        }
        if chat.session.conversation.isChatEnded || chat.session.connection.isReadOnly {
            chat.update { $0.startNewChatAfterClosure(at: now()) }
            guard await waitForConnection.execute(restartingFirst: true) else { return false }
        }
        chat.update { $0.conversation.markNewChatStartedIfNeeded() }
        if !chat.isConnected {
            return await waitForConnection.execute(restartingFirst: false)
        }
        return true
    }
}
