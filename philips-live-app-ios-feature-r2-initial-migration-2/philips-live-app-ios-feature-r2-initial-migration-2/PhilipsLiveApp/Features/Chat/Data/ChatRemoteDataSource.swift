import Foundation
@preconcurrency import MessengerTransport
import OSLog

protocol ChatRemoteDataSource: AnyObject {
    var events: AsyncStream<ChatEvent> { get }
    /// Messages and uploads can go through: the chat is configured and its transport connected.
    var isConnected: Bool { get }
    /// Connects the chat, or does nothing if a client for this configuration is already connected or connecting. A
    /// different configuration replaces the client. Callers that arrive while a client is being opened for the same
    /// configuration wait for it.
    func start(_ configuration: ChatConfiguration) async throws
    /// Starts again with `configuration`. A chat that went read-only begins a new conversation on the same client
    /// if the configuration is unchanged, and a client that is connecting, connected or reconnecting for it is left
    /// to the SDK; any other client is replaced. Callers that arrive while a client is being opened for the same
    /// configuration wait for it, and ones that arrive while a new conversation is being started return at once.
    func restart(_ configuration: ChatConfiguration) async throws
    /// Sends the text. The message the SDK inserts for it is reported with `localId`, so it is the message the user
    /// sees and not a lookalike.
    func send(_ text: String, localId: String) async throws
    /// Uploads the files concurrently and returns the ones not cancelled, in order, once every one is uploaded. If any
    /// upload fails or stalls, all of them are detached and the call throws, so a message is never sent with only some
    /// of the files the user chose. A connection lost meanwhile throws `ChatError.notConnected` at once.
    func attach(_ files: [AttachmentUpload]) async throws -> [UploadedAttachment]
    /// Stops the upload of one file, whether the SDK has it yet or not, without affecting the others.
    func cancelUpload(pendingId: PendingAttachment.ID)
    /// The newest page of the conversation as Genesys has it, to find out whether a message arrived that no
    /// confirmation was seen for. Throws if the chat is not connected or does not answer in time.
    func recentMessages() async throws -> [ChatMessage]
    /// Asks for a fresh link to a received attachment, as the SDK's links expire, and waits for it to arrive. A
    /// cancelled request throws `CancellationError` at once.
    func attachmentURL(forId id: String) async throws -> URL
    /// Shuts the client down and cancels a connection that is still being opened, so the `start` and `restart` calls
    /// waiting for it throw `CancellationError`.
    func disconnect()
    /// Sends the request. The chat answers later with `conversationClearAnswered`.
    func clearConversation() throws
}

/// Owns the Genesys messaging client.
final class GenesysChatRemoteDataSource: ChatRemoteDataSource {
    private static let reconnectionTimeoutSeconds: Int64 = 5 * 60
    private static let historyTimeout: Duration = .seconds(5)
    /// The attribute the shared deployment's flow reads to route by country.
    private static let userCountryAttribute = "userCountry"

    let events: AsyncStream<ChatEvent>
    private let continuation: AsyncStream<ChatEvent>.Continuation

    private var client: MessagingClient?
    private var configuration: ChatConfiguration?
    private var connection: Task<Void, Error>?
    /// `startNewChat()` only asks Genesys to close the read-only session; the state leaves ReadOnly later.
    private var isStartingNewChat = false
    private var isConfigured = false
    private var isClientConnected = false
    private var isConversationClearEnabled = false
    /// The local ids of the messages sent, in order, until the SDK's insertion of each has been reported.
    private var sentLocalIds: [String] = []
    private var historyRequest: CheckedContinuation<[ChatMessage], Error>?
    private var historyTimer: Task<Void, Never>?
    private let attachments = GenesysPendingAttachments()
    private let links = GenesysAttachmentLinks()
    private let logger = Logger(category: "ChatRemoteDataSource")

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    var isConnected: Bool {
        isConfigured && isClientConnected
    }

    func start(_ configuration: ChatConfiguration) async throws {
        if let connection, configuration == self.configuration {
            try await connection.value
        }
        if let client, configuration == self.configuration {
            try resume(client)
        } else {
            try await open(configuration)
        }
    }

    func restart(_ configuration: ChatConfiguration) async throws {
        if let connection, configuration == self.configuration {
            try await connection.value
            return
        }
        if let client, configuration == self.configuration {
            let state = client.currentState
            if state is MessagingClientState.ReadOnly {
                guard !isStartingNewChat else { return }
                do {
                    try client.startNewChat()
                } catch {
                    throw ChatSdkMapper.error(error)
                }
                isStartingNewChat = true
                return
            }
            if Self.isLive(state) {
                try resume(client)
                return
            }
        }
        try await open(configuration)
    }

    func send(_ text: String, localId: String) async throws {
        guard isConfigured, let client else {
            throw ChatError.notConfigured
        }
        try await attachments.prepareToSend(using: client)
        // A replaced client took its batch with it.
        guard self.client === client else {
            throw ChatError.notConfigured
        }
        guard isConfigured else {
            await attachments.discardPending(using: client)
            throw ChatError.notConfigured
        }
        sentLocalIds.append(localId)
        do {
            try client.sendMessage(text: text, customAttributes: [:])
        } catch {
            sentLocalIds.removeLast()
            await attachments.discardPending(using: client)
            throw ChatSdkMapper.error(error)
        }
        attachments.reset()
    }

    func attach(_ files: [AttachmentUpload]) async throws -> [UploadedAttachment] {
        guard isConnected, let client else {
            throw ChatError.notConnected
        }
        await attachments.prepareForUpload(using: client)
        let byteArrays = await KotlinByteArray.copies(of: files.map(\.data))
        guard isConnected, let activeClient = self.client else {
            throw ChatError.notConnected
        }
        let items = zip(files, byteArrays).map {
            AttachmentBytes(fileName: $0.fileName, bytes: $1.value, pendingId: $0.pendingId)
        }
        return try await attachments.upload(items, using: activeClient)
    }

    func cancelUpload(pendingId: PendingAttachment.ID) {
        guard let client else { return }
        attachments.cancel(pendingId: pendingId, using: client)
    }

    func attachmentURL(forId id: String) async throws -> URL {
        guard isConnected, let client else {
            throw ChatError.notConnected
        }
        return try await links.url(forId: id, using: client)
    }

    func recentMessages() async throws -> [ChatMessage] {
        guard isConnected, let client, historyRequest == nil else {
            throw ChatError.notConnected
        }
        return try await withCheckedThrowingContinuation { continuation in
            historyRequest = continuation
            historyTimer = Task {
                try? await Task.sleep(for: Self.historyTimeout)
                guard !Task.isCancelled else { return }
                finishHistory(.failure(ChatError.notConnected))
            }
            Task {
                do {
                    try await client.fetchNextPage()
                } catch {
                    finishHistory(.failure(ChatSdkMapper.error(error)))
                }
            }
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        tearDownClient()
    }

    func clearConversation() throws {
        guard let client else {
            throw ChatError.notConfigured
        }
        do {
            try client.clearConversation()
        } catch {
            throw ChatSdkMapper.error(error)
        }
    }
}

// MARK: - Listeners

private extension GenesysChatRemoteDataSource {
    /// Callbacks are queued to the main queue, so some run after the client was replaced and are ignored.
    func attachListeners(to client: MessagingClient) {
        let source = ClientReference(client: client)
        client.stateChangedListener = { @Sendable [weak self] change in
            DispatchQueue.main.async {
                guard let self, self.isCurrent(source) else { return }
                self.handle(state: change.newState)
            }
        }
        client.messageListener = { @Sendable [weak self] event in
            DispatchQueue.main.async {
                guard let self, self.isCurrent(source) else { return }
                self.handle(messageEvent: event)
            }
        }
        client.eventListener = { @Sendable [weak self] event in
            DispatchQueue.main.async {
                guard let self, self.isCurrent(source) else { return }
                self.handle(event: event)
            }
        }
    }

    func isCurrent(_ source: ClientReference) -> Bool {
        guard let client = source.client else { return false }
        return self.client === client
    }

    func handle(state: MessagingClientState) {
        if !(state is MessagingClientState.ReadOnly) {
            isStartingNewChat = false
        }
        if ChatSdkMapper.isNetworkFailure(state) {
            continuation.yield(.sdkNetworkAvailability(false))
        }
        switch state {
            case is MessagingClientState.Connected, is MessagingClientState.Configured:
                isConfigured = state is MessagingClientState.Configured
                isClientConnected = true
                continuation.yield(.sdkNetworkAvailability(true))
                emitConnectionState()
            case is MessagingClientState.Reconnecting:
                isClientConnected = false
                emitConnectionState()
            case is MessagingClientState.Closing, is MessagingClientState.Closed,
                 is MessagingClientState.Error, is MessagingClientState.Idle:
                isConfigured = false
                isClientConnected = false
                if Self.isDown(state) {
                    attachments.reset()
                }
                emitConnectionState(failure: ChatSdkMapper.failure(of: state))
            case is MessagingClientState.ReadOnly:
                isConfigured = true
                isClientConnected = false
                continuation.yield(.readOnly)
            default:
                break
        }
    }

    func handle(messageEvent: MessageEvent) {
        if let updated = messageEvent as? MessageEvent.AttachmentUpdated {
            handle(attachment: updated.attachment)
        } else if let history = messageEvent as? MessageEvent.HistoryFetched {
            finishHistory(.success(history.messages.map(ChatSdkMapper.message)))
        } else if let event = ChatSdkMapper.event(messageEvent) {
            logSender(of: event)
            continuation.yield(claimingLocalId(event))
        }
    }

    func logSender(of event: ChatEvent) {
        let sender: ChatSender? = switch event {
            case let .messageInserted(message): message.sender
            case let .quickReplyReceived(_, _, quickReplySender): quickReplySender
            default: nil
        }
        guard let sender else { return }
        let (kind, name, image) = (sender.kind.rawValue, sender.name ?? "nil", sender.imageUrl ?? "nil")
        logger.info("Sender \(kind, privacy: .public) name=\(name, privacy: .public) image=\(image, privacy: .public)")
    }

    /// Answers the waiting `recentMessages` call once, whichever of the page, a failure or the timeout comes first.
    func finishHistory(_ result: Result<[ChatMessage], Error>) {
        historyTimer?.cancel()
        guard let request = historyRequest else { return }
        historyRequest = nil
        request.resume(with: result)
    }

    /// The SDK inserts the message of a send, still sending, as `sendMessage` runs, and the events are reported in
    /// that order. So the next such insertion is the message of the oldest send not reported yet. One that arrives
    /// already sent comes from elsewhere, e.g. another device.
    func claimingLocalId(_ event: ChatEvent) -> ChatEvent {
        guard case let .messageInserted(inserted) = event, inserted.isFromUser, inserted.state == .sending,
              !sentLocalIds.isEmpty
        else { return event }
        var message = inserted
        message.localId = sentLocalIds.removeFirst()
        return .messageInserted(message)
    }

    func handle(event: Event) {
        if let failure = event as? Event.Error {
            logger.error(
                "SDK error \(String(describing: failure.errorCode)): \(failure.message ?? "-") (\(String(describing: failure.correctiveAction)))"
            )
        }
        if let event = ChatSdkMapper.event(event) {
            continuation.yield(event)
        }
    }

    func handle(attachment: Attachment) {
        let state = ChatSdkMapper.uploadState(attachment.state)
        let downloadUrl = ChatSdkMapper.downloadUrl(attachment.state)
        if let failure = attachment.state as? Attachment.StateError {
            logger.error(
                "Attachment \(attachment.fileName ?? "?") failed: \(String(describing: failure.errorCode)) - \(failure.errorMessage)"
            )
        } else {
            logger.info("Attachment \(attachment.fileName ?? "?") state: \(String(describing: state))")
        }
        attachments.recordUpdate(id: attachment.id, state: state)
        continuation.yield(.attachmentUpdated(
            id: attachment.id,
            pendingId: attachments.pendingId(forSdkId: attachment.id),
            state: state,
            downloadUrl: downloadUrl
        ))
        links.recordUpdate(id: attachment.id, state: state, downloadUrl: downloadUrl)
    }

    func emitConnectionState(failure: ChatConnectionError? = nil) {
        continuation.yield(.connectionState(
            isConfigured: isConfigured,
            connected: isClientConnected,
            conversationClearEnabled: isConversationClearEnabled,
            failure: failure
        ))
    }
}

// MARK: - Client lifecycle

private extension GenesysChatRemoteDataSource {
    /// Replaces the current client, so there is never more than one.
    func open(_ configuration: ChatConfiguration) async throws {
        disconnect()
        self.configuration = configuration
        let task = Task { try await openClient(configuration) }
        connection = task
        defer {
            if connection == task {
                connection = nil
            }
        }
        try await task.value
    }

    func openClient(_ configuration: ChatConfiguration) async throws {
        let sdk = MessengerTransportSDK(configuration: Configuration(
            deploymentId: configuration.deploymentId,
            domain: configuration.domain,
            logging: false,
            reconnectionTimeoutInSeconds: Self.reconnectionTimeoutSeconds,
            autoRefreshTokenWhenExpired: true,
            encryptedVault: true
        ))

        let isConversationClearEnabled: Bool
        do {
            isConversationClearEnabled = try await Self.fetchConversationClearEnabled(sdk)
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatSdkMapper.error(error)
        }
        try Task.checkCancellation()
        self.isConversationClearEnabled = isConversationClearEnabled

        let client = sdk.createMessagingClient()
        if let userCountry = configuration.userCountry {
            _ = client.customAttributesStore.add(customAttributes: [Self.userCountryAttribute: userCountry])
        }
        self.client = client
        attachListeners(to: client)
        try connect(client)
    }

    /// Reconnects a client that is down; one that is connecting, connected or reconnecting is left to the SDK. A
    /// connected one reports nothing new, so its state is sent again for callers that expect an answer.
    func resume(_ client: MessagingClient) throws {
        if isConnected {
            emitConnectionState()
        } else if !isConfigured, !isClientConnected, Self.isDown(client.currentState) {
            try connect(client)
        }
    }

    func connect(_ client: MessagingClient) throws {
        do {
            try client.connect()
        } catch {
            tearDownClient()
            throw ChatSdkMapper.error(error)
        }
    }

    /// Removes the listeners first, so nothing the closing client reports changes the state of its replacement. Its
    /// state is reported even if it was not connected, as the closing client never reports it itself.
    func tearDownClient() {
        let hadClient = client != nil
        if let client {
            client.stateChangedListener = nil
            client.messageListener = nil
            client.eventListener = nil
            if !Self.isDown(client.currentState) {
                do {
                    try client.disconnect()
                } catch {
                    logger.error("Disconnect failed: \(error)")
                }
            }
        }
        client = nil
        sentLocalIds = []
        finishHistory(.failure(ChatError.notConnected))
        isStartingNewChat = false
        isConfigured = false
        isClientConnected = false
        attachments.reset()
        links.reset()
        if hadClient {
            emitConnectionState()
        }
    }

    /// The SDK is connecting, connected or reconnecting on its own, so replacing the client would only restart it.
    static func isLive(_ state: MessagingClientState) -> Bool {
        state is MessagingClientState.Connecting || state is MessagingClientState.Connected
            || state is MessagingClientState.Configured || state is MessagingClientState.Reconnecting
    }

    /// The SDK only connects a client that is closed, idle or failed, and rejects disconnecting one that is.
    static func isDown(_ state: MessagingClientState) -> Bool {
        state is MessagingClientState.Closed || state is MessagingClientState.Idle
            || state is MessagingClientState.Error
    }
}

// MARK: - SDK interop

private extension GenesysChatRemoteDataSource {
    /// Lets a queued callback tell which client it came from. Weak, as the client stores the listeners, and a freed
    /// client reads as `nil` rather than as a new client that took its address.
    nonisolated struct ClientReference: @unchecked Sendable {
        weak var client: MessagingClient?
    }

    /// Whether the deployment lets the user end the chat. A deployment that is switched off throws `unavailable`.
    static func fetchConversationClearEnabled(_ sdk: MessengerTransportSDK) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            sdk.fetchDeploymentConfig { @Sendable config, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if config?.status == DeploymentConfig.Status.inactive {
                    continuation.resume(throwing: ChatError.unavailable)
                } else {
                    continuation
                        .resume(returning: config?.messenger.apps.conversations.conversationClear.enabled ?? false)
                }
            }
        }
    }
}
