import Foundation
import OSLog

protocol ConnectChatUseCase {
    func execute(_ trigger: ChatConnectionTrigger)
}

/// Starts, resumes or recovers the chat session while the chat screen is open.
struct DefaultConnectChatUseCase: ConnectChatUseCase {
    /// iOS closes the sockets of a suspended app, so a connection left alone this long is assumed dead.
    private static let awayLimit: TimeInterval = 20

    private let chat: ChatRepository
    private let getConfiguration: GetChatConfigurationUseCase
    private let restart: RestartChatUseCase
    private let now: () -> Date
    private let logger = Logger(category: "ConnectChatUseCase")

    init(
        chat: ChatRepository,
        getConfiguration: GetChatConfigurationUseCase,
        restart: RestartChatUseCase,
        now: @escaping () -> Date = Date.init
    ) {
        self.chat = chat
        self.getConfiguration = getConfiguration
        self.restart = restart
        self.now = now
    }

    func execute(_ trigger: ChatConnectionTrigger) {
        switch trigger {
            case .screenAppeared:
                chat.update { $0.screenDidAppear() }
            case .retryTapped:
                chat.disconnect()
                chat.update { $0.connection.prepareRetry() }
            case .networkRestored:
                guard !confirmConnected(), !chat.session.connection.isConfigured else { return }
                chat.update { $0.connection.prepareRetry() }
            case .appBecameActive:
                guard restartAfterReturn() else { return }
        }
        initializeSession()
    }

    /// A connection still up after a short absence is kept, and one the SDK is reconnecting is left to it. After a
    /// long absence, or when the connection is down, the SDK's client is replaced: it can be dead without having
    /// noticed, and one whose session expired cannot be resumed. An upload in flight is never cut off.
    private func restartAfterReturn() -> Bool {
        let session = chat.session
        let wasAway = session.connection.backgroundedAt.map { now().timeIntervalSince($0) >= Self.awayLimit } ?? false
        chat.update { $0.connection.markReturned() }
        guard session.isScreenActive, !session.conversation.isChatEnded, !session.tray.isSending else { return false }
        if !wasAway, confirmConnected() || session.connection.isConfigured {
            return false
        }
        chat.disconnect()
        chat.update { $0.connection.prepareRetry() }
        return true
    }

    private func confirmConnected() -> Bool {
        guard chat.isConnected else { return false }
        chat.update { $0.connection.markConnected() }
        return true
    }

    private func initializeSession() {
        guard chat.session.isScreenActive, !chat.session.connection.isSessionInitialized else { return }
        guard chat.session.connection.isNetworkAvailable else {
            chat.update { $0.connection.markOffline() }
            return
        }
        chat.update { $0.connection.beginConnecting() }

        if chat.session.conversation.isChatEnded {
            chat.update { $0.conversation.resumeAfterEnd() }
            Task { try? await restart.execute() }
        } else if chat.session.conversation.didRestartAfterEnd {
            Task { try? await restart.execute() }
        } else {
            chat.update { $0.conversation.activate() }
            guard let configuration = getConfiguration.execute() else {
                logger.error("Chat connection failed: \(ChatError.missingConfiguration)")
                chat.update { $0.connection.fail(.missingConfiguration) }
                return
            }
            Task {
                do {
                    try await chat.connect(configuration)
                } catch is CancellationError {
                    return
                } catch {
                    logger.error("Chat connection failed: \(error)")
                    chat.update { $0.connection.fail(ChatError(classifying: error).connectionError) }
                }
            }
        }
    }
}
