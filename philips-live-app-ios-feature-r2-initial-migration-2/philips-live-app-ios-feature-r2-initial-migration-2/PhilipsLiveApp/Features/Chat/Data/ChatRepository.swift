import Foundation
import OSLog

protocol ChatRepository: AnyObject {
    var session: ChatSession { get }
    /// Messages and uploads can go through: the chat is configured and its transport connected.
    var isConnected: Bool { get }
    func sessions() -> AsyncStream<ChatSession>
    /// Changes the session through its named transitions.
    func update(_ transition: (inout ChatSession) -> Void)
    /// Runs `work` after every send queued before it has finished, so messages reach the chat in the order the
    /// user sent them.
    @discardableResult
    func inSendOrder<Output: Sendable>(_ work: @escaping @MainActor () async -> Output) -> Task<Output, Never>
    func connect(_ configuration: ChatConfiguration) async throws
    /// Starts again with `configuration`, which may differ from the last start's (the support country changed).
    func restart(_ configuration: ChatConfiguration) async throws
    func disconnect()
    func send(_ text: String, localId: String) async throws
    /// Uploads the files and returns the ones that were not cancelled meanwhile.
    func attach(_ files: [AttachmentUpload]) async throws -> [UploadedAttachment]
    /// Stops the upload of one tray item while the others carry on.
    func cancelUpload(pendingId: PendingAttachment.ID)
    /// The newest page of the conversation as Genesys has it. Throws if the chat is not connected or does not answer.
    func recentMessages() async throws -> [ChatMessage]
    /// Asks for a fresh link to a received attachment and waits for it.
    func attachmentURL(forId id: String) async throws -> URL
    /// Sends the request. The chat answers later with an event that changes the session.
    func clearConversation() throws
}

/// The app-wide chat session: restores and saves it, keeps it in step with the chat and publishes it.
final class DefaultChatRepository: ChatRepository {
    private static let defaultTypingMilliseconds: Int64 = 3000
    private static let logger = Logger(category: "ChatRepository")

    private(set) var session: ChatSession {
        didSet {
            guard session != oldValue else { return }
            persistChanges(from: oldValue)
            continuations.values.forEach { $0.yield(session) }
        }
    }

    private let remote: ChatRemoteDataSource
    private let local: ChatLocalDataSource
    private let attachments: ChatAttachmentRepository
    private let now: () -> Date
    /// False while the Keychain could not be read: the saved chat stays untouched, as saving would overwrite it.
    private var isHistoryLoaded: Bool
    private var continuations: [UUID: AsyncStream<ChatSession>.Continuation] = [:]
    private var listeners: [Task<Void, Never>] = []
    private var typingTask: Task<Void, Never>?
    private var sendQueueTail: Task<Void, Never>?

    init(
        remote: ChatRemoteDataSource,
        local: ChatLocalDataSource,
        attachments: ChatAttachmentRepository,
        connectivity: ConnectivityProvider,
        now: @escaping () -> Date = Date.init
    ) {
        self.remote = remote
        self.local = local
        self.attachments = attachments
        self.now = now
        let loaded = Self.loadHistory(from: local).map { Self.restoring($0, previews: attachments) }
        isHistoryLoaded = loaded != nil
        session = ChatSession(
            conversation: ChatConversation(restoring: loaded ?? PersistedChat()),
            connection: ChatConnection(isNetworkAvailable: connectivity.isConnected)
        )
        if let loaded {
            Self.removeFiles(notIn: loaded, from: attachments)
        }
        listeners = [
            Task { [weak self, events = remote.events] in
                for await event in events {
                    self?.handle(event)
                }
            },
            Task { [weak self, updates = connectivity.updates()] in
                for await isConnected in updates {
                    self?.update { $0.applyNetworkChange(isConnected: isConnected) }
                }
            },
        ]
    }

    deinit {
        listeners.forEach { $0.cancel() }
        typingTask?.cancel()
    }

    var isConnected: Bool {
        remote.isConnected
    }

    func sessions() -> AsyncStream<ChatSession> {
        restoreHistoryIfNeeded()
        return AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(session)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
        }
    }

    func update(_ transition: (inout ChatSession) -> Void) {
        var next = session
        transition(&next)
        session = next
    }

    @discardableResult
    func inSendOrder<Output: Sendable>(_ work: @escaping @MainActor () async -> Output) -> Task<Output, Never> {
        let previous = sendQueueTail
        let task = Task { () -> Output in
            await previous?.value
            return await work()
        }
        sendQueueTail = Task { _ = await task.value }
        return task
    }

    func connect(_ configuration: ChatConfiguration) async throws {
        try await remote.start(configuration)
    }

    func restart(_ configuration: ChatConfiguration) async throws {
        try await remote.restart(configuration)
    }

    func disconnect() {
        remote.disconnect()
    }

    func send(_ text: String, localId: String) async throws {
        try await remote.send(text, localId: localId)
    }

    func attach(_ files: [AttachmentUpload]) async throws -> [UploadedAttachment] {
        try await remote.attach(files)
    }

    func cancelUpload(pendingId: PendingAttachment.ID) {
        remote.cancelUpload(pendingId: pendingId)
    }

    func recentMessages() async throws -> [ChatMessage] {
        try await remote.recentMessages()
    }

    func attachmentURL(forId id: String) async throws -> URL {
        try await remote.attachmentURL(forId: id)
    }

    func clearConversation() throws {
        try remote.clearConversation()
    }
}

private extension DefaultChatRepository {
    /// The SDK's echo of an own message gets its local previews back before it is merged into the session.
    func handle(_ event: ChatEvent) {
        var event = event
        if case let .messageInserted(message) = event {
            event = .messageInserted(attachments.applyingPreviews(to: message))
        }
        let newLocalId = UUID().uuidString
        update { $0.apply(event, at: now(), newLocalId: newLocalId) }
        if case let .agentTyping(milliseconds) = event {
            expireAgentTyping(afterMilliseconds: milliseconds)
        } else if !session.isAgentTyping {
            typingTask?.cancel()
        }
    }

    /// The agent's typing state lasts for the duration the SDK reports.
    func expireAgentTyping(afterMilliseconds milliseconds: Int64?) {
        typingTask?.cancel()
        let duration = milliseconds.flatMap { $0 > 0 ? $0 : nil } ?? Self.defaultTypingMilliseconds
        typingTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(duration))
            guard !Task.isCancelled else { return }
            self?.update { $0.hideAgentTyping() }
        }
    }

    /// A Keychain read that failed at launch, e.g. in the background before the first unlock, is tried again once
    /// the chat is observed, as long as the conversation is still the empty one it fell back to.
    func restoreHistoryIfNeeded() {
        guard !isHistoryLoaded, session.conversation == ChatConversation(),
              let loaded = Self.loadHistory(from: local).map({ Self.restoring($0, previews: attachments) })
        else { return }
        update { $0.conversation.restore(loaded) }
        isHistoryLoaded = true
        Self.removeFiles(notIn: loaded, from: attachments)
    }

    static func loadHistory(from local: ChatLocalDataSource) -> PersistedChat? {
        do {
            return try local.load()
        } catch {
            logger.error("Saved chat could not be read from the Keychain and is left as it is: \(error)")
            return nil
        }
    }

    static func restoring(_ saved: PersistedChat, previews: ChatAttachmentRepository) -> PersistedChat {
        var saved = saved
        saved.messages = identified(previews.resolvingLocalFiles(in: saved.messages))
        saved.oldMessages = identified(previews.resolvingLocalFiles(in: saved.oldMessages))
        return saved
    }

    /// Previews are kept for the whole history, other local copies only while their message can be sent again.
    static func removeFiles(notIn saved: PersistedChat, from previews: ChatAttachmentRepository) {
        let messages = saved.messages + saved.oldMessages
        let previewUris = messages.flatMap(\.attachments).compactMap(\.previewUri)
        let unsentFileUris = messages.filter { $0.isFromUser && $0.state != .sent }.flatMap(\.attachments)
            .compactMap(\.localFileUri)
        let keptFiles = Set((previewUris + unsentFileUris).compactMap(URL.init(string:)))
        Task { await previews.removeFiles(except: keptFiles) }
    }

    /// Messages saved without any id (e.g. by R1) get a local one, so every message keeps one identity.
    static func identified(_ messages: [ChatMessage]) -> [ChatMessage] {
        messages.map { message in
            guard message.id == nil, message.localId == nil else { return message }
            var message = message
            message.localId = UUID().uuidString
            return message
        }
    }

    func persistChanges(from old: ChatSession) {
        guard isHistoryLoaded else { return }
        let (new, old) = (session.conversation.persisted, old.conversation.persisted)
        if new.messages != old.messages {
            local.saveMessages(new.messages)
        }
        if new.oldMessages != old.oldMessages {
            local.saveOldMessages(new.oldMessages)
        }
        if new.closedAt != old.closedAt {
            local.saveClosedAt(new.closedAt)
        }
        if new.previousClosedAt != old.previousClosedAt {
            local.savePreviousClosedAt(new.previousClosedAt)
        }
    }
}
