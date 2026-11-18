import Foundation

protocol SendTextMessageUseCase {
    /// Shows the text in the chat at once and hands it to the chat in the order it was sent.
    func execute(_ text: String)
}

struct DefaultSendTextMessageUseCase: SendTextMessageUseCase {
    private let chat: ChatRepository
    private let deliver: DeliverTextMessageUseCase
    private let now: () -> Date

    init(chat: ChatRepository, deliver: DeliverTextMessageUseCase, now: @escaping () -> Date = Date.init) {
        self.chat = chat
        self.deliver = deliver
        self.now = now
    }

    /// Sending into a closed chat starts a new conversation, so the connection is restarted for it.
    func execute(_ text: String) {
        let restart = chat.session.conversation.isChatEnded || chat.session.connection.isReadOnly
        let message = ChatMessage(
            localId: UUID().uuidString,
            direction: .inbound,
            text: text,
            state: .sending,
            timestamp: now()
        )
        chat.update {
            if restart {
                $0.startNewChatAfterClosure(at: now())
            }
            $0.conversation.markNewChatStartedIfNeeded()
            $0.conversation.appendLocalMessage(message)
        }
        chat.inSendOrder { await deliver.execute(message, restart: restart, replacing: nil) }
    }
}
