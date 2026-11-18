import Foundation

protocol EndChatUseCase {
    /// Asks the chat to clear the conversation and returns once it confirmed; the chat then counts as ended. Throws
    /// if the chat refuses or does not answer in time.
    func execute() async throws
}

/// A second request while ending, or after the chat ended, does nothing.
struct DefaultEndChatUseCase: EndChatUseCase {
    private static let confirmationTimeout: Duration = .seconds(10)

    private let chat: ChatRepository

    init(chat: ChatRepository) {
        self.chat = chat
    }

    func execute() async throws {
        guard !chat.session.isEndingChat, !chat.session.conversation.isChatEnded else { return }
        chat.update { $0.beginEndingChat() }
        defer { chat.update { $0.finishEndingChat() } }
        try chat.clearConversation()
        guard await isClearConfirmed() else {
            throw ChatError.conversationNotCleared
        }
    }

    /// Waits for the chat's answer; cancelling the wait at the timeout ends the stream, so a clear applied just then
    /// is read from the session.
    private func isClearConfirmed() async -> Bool {
        let answer = Task {
            for await session in chat.sessions() where session.conversation.isChatEnded || session.didClearFail {
                return session.conversation.isChatEnded
            }
            return false
        }
        let timeout = Task {
            try? await Task.sleep(for: Self.confirmationTimeout)
            answer.cancel()
        }
        defer { timeout.cancel() }
        return await answer.value || chat.session.conversation.isChatEnded
    }
}
