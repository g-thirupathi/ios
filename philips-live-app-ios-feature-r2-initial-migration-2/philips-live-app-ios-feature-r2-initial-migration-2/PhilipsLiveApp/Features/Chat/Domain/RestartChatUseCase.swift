import OSLog

protocol RestartChatUseCase {
    /// Restarts the chat with the current support country's configuration, which also starts it if it never did.
    func execute() async throws
}

struct DefaultRestartChatUseCase: RestartChatUseCase {
    private let chat: ChatRepository
    private let getConfiguration: GetChatConfigurationUseCase
    private let logger = Logger(category: "RestartChatUseCase")

    init(chat: ChatRepository, getConfiguration: GetChatConfigurationUseCase) {
        self.chat = chat
        self.getConfiguration = getConfiguration
    }

    func execute() async throws {
        chat.update { $0.connection.markReconnecting() }
        guard let configuration = getConfiguration.execute() else {
            fail(.missingConfiguration, ChatError.missingConfiguration)
            throw ChatError.missingConfiguration
        }
        do {
            try await chat.restart(configuration)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            fail(ChatError(classifying: error).connectionError, error)
            throw error
        }
    }

    private func fail(_ reason: ChatConnectionError, _ error: Error) {
        logger.error("Chat connection failed: \(error)")
        chat.update { $0.connection.fail(reason) }
    }
}
