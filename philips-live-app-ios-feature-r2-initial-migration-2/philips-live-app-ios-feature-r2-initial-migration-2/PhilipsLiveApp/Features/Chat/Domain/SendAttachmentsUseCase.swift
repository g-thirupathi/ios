import Foundation
import OSLog

protocol SendAttachmentsUseCase {
    /// Uploads the tray and sends the text with it. Returns whether the message was created.
    func execute(_ text: String) async -> Bool
}

/// The upload is all or nothing, and only then is the message shown and handed to the chat. Before the message
/// exists a failure leaves the tray and text as they were; after, it is a failed message with retry. Taking a file
/// out of the tray meanwhile cancels just that file, and if none is left nothing is sent. Connecting (getting the chat
/// ready and reconnecting) has one time budget and uploading another, each shared by every wait and retry of the send,
/// so they cannot add up. A stalled upload ends earlier, when the chat sees no progress.
struct DefaultSendAttachmentsUseCase: SendAttachmentsUseCase {
    private static let maxReconnects = 3
    private static let connectTimeout: Duration = .seconds(90)
    private static let uploadTimeout: Duration = .seconds(600)

    private let chat: ChatRepository
    private let attachments: ChatAttachmentRepository
    private let prepareTransport: PrepareAttachmentTransportUseCase
    private let waitForConnection: WaitForChatConnectionUseCase
    private let watchDelivery: WatchDeliveryUseCase
    private let now: () -> Date
    private let logger = Logger(category: "SendAttachmentsUseCase")

    init(
        chat: ChatRepository,
        attachments: ChatAttachmentRepository,
        prepareTransport: PrepareAttachmentTransportUseCase,
        waitForConnection: WaitForChatConnectionUseCase,
        watchDelivery: WatchDeliveryUseCase,
        now: @escaping () -> Date = Date.init
    ) {
        self.chat = chat
        self.attachments = attachments
        self.prepareTransport = prepareTransport
        self.waitForConnection = waitForConnection
        self.watchDelivery = watchDelivery
        self.now = now
    }

    func execute(_ text: String) async -> Bool {
        guard !chat.session.tray.isSending else { return false }
        guard chat.session.connection.isNetworkAvailable else {
            chat.update { $0.tray.showAlert(.networkError) }
            return false
        }
        chat.update { $0.tray.beginSend() }
        return await chat.inSendOrder { await uploadAndHandOver(text) }.value
    }
}

private extension DefaultSendAttachmentsUseCase {
    enum Outcome {
        case uploaded([ChatAttachment])
        case cancelled
        case failed(AttachmentAlert, isConnectionLost: Bool)
    }

    /// The time left for one kind of waiting, counted over every wait of a send.
    struct TimeBudget {
        private(set) var remaining: Duration

        init(_ limit: Duration) {
            remaining = limit
        }

        /// Runs the work and cancels it when the time left runs out, returning nil then. The waits and uploads in
        /// the work all stop when their task is cancelled.
        mutating func run<Output: Sendable>(_ work: @escaping @MainActor () async -> Output) async -> Output? {
            guard remaining > .zero else { return nil }
            let limit = remaining
            let clock = ContinuousClock()
            let start = clock.now
            let task = Task { await work() }
            let timer = Task { () -> Bool in
                do {
                    try await Task.sleep(for: limit)
                } catch {
                    return false
                }
                task.cancel()
                return true
            }
            let output = await task.value
            timer.cancel()
            let isTimedOut = await timer.value
            remaining = max(remaining - (clock.now - start), .zero)
            return isTimedOut ? nil : output
        }
    }

    func uploadAndHandOver(_ text: String) async -> Bool {
        let batch = chat.session.tray.items
        let uploaded: [ChatAttachment]
        switch await prepareAndUpload(batch) {
            case let .uploaded(files):
                uploaded = files
            case .cancelled:
                chat.update { $0.tray.cancelSend() }
                return false
            case let .failed(alert, isConnectionLost):
                chat.update { $0.failAttachmentSend(alert: alert, isConnectionLost: isConnectionLost) }
                return false
        }
        attachments.registerSent(uploaded)
        let localId = UUID().uuidString
        let message = ChatMessage(
            localId: localId,
            direction: .inbound,
            text: text,
            state: .sending,
            timestamp: now(),
            attachments: uploaded
        )
        chat.update {
            $0.conversation.appendLocalMessage(message)
            $0.tray.finishSend(sentIds: Set(batch.map(\.id)))
        }
        do {
            try await chat.send(text, localId: localId)
            watchDelivery.execute(message)
        } catch {
            logger.error("Send message with attachments failed: \(error)")
            chat.update { $0.conversation.markNotSent(message) }
        }
        return true
    }

    func prepareAndUpload(_ batch: [PendingAttachment]) async -> Outcome {
        var connecting = TimeBudget(Self.connectTimeout)
        var uploading = TimeBudget(Self.uploadTimeout)
        guard let isReady = await connecting.run({ await prepareTransport.execute() }) else {
            return timedOut(batch)
        }
        guard isReady else {
            let isUnavailable = chat.session.connection.error == .missingConfiguration
            return .failed(isUnavailable ? .chatUnavailable : .networkError, isConnectionLost: !isUnavailable)
        }
        return await upload(batch, connecting: &connecting, uploading: &uploading)
    }

    /// Uploads the files still in the tray concurrently. A lost connection restarts the chat and the whole batch.
    func upload(
        _ batch: [PendingAttachment],
        connecting: inout TimeBudget,
        uploading: inout TimeBudget
    ) async -> Outcome {
        var reconnects = 0
        while true {
            let files = batch.filter(isInTray)
            guard let attempt = await uploading.run({ await attemptUpload(files) }) else {
                return timedOut(batch)
            }
            let error: Error
            switch attempt {
                case let .success(outcome):
                    return outcome
                case let .failure(failure):
                    error = failure
            }
            let failure = ChatError(classifying: error)
            if failure.isNotConnected, chat.session.connection.isNetworkAvailable, reconnects < Self.maxReconnects {
                let reconnected = await connecting.run { await waitForConnection.execute(restartingFirst: true) }
                guard let reconnected else { return timedOut(batch) }
                if reconnected {
                    reconnects += 1
                    continue
                }
            }
            logger.error("Uploading attachments failed: \(error)")
            let isConnectionLost = failure.isNotConnected || !chat.session.connection.isNetworkAvailable
            return .failed(
                Self.alert(for: failure, isConnectionLost: isConnectionLost, in: batch),
                isConnectionLost: isConnectionLost
            )
        }
    }

    func attemptUpload(_ files: [PendingAttachment]) async -> Result<Outcome, Error> {
        do {
            var uploads: [AttachmentUpload] = []
            for file in files where isInTray(file) {
                do {
                    let data = try await attachments.data(at: file.fileURL)
                    logger.info("Uploading \(file.fileName) (\(data.count) bytes, mime: \(file.mimeType ?? "nil"))")
                    uploads.append(AttachmentUpload(data: data, fileName: file.fileName, pendingId: file.id))
                } catch {
                    // Removing a file deletes it, which can happen while it is read.
                    guard isInTray(file) else { continue }
                    throw ChatError.attachFailed(fileName: file.fileName, cause: error)
                }
            }
            guard !uploads.isEmpty else { return .success(.cancelled) }
            let uploaded = try await chat.attach(uploads)
            return .success(outcome(of: uploaded, for: files))
        } catch {
            return .failure(error)
        }
    }

    /// A budget ran out. With the chat down that is a lost connection, otherwise the upload itself failed.
    func timedOut(_ batch: [PendingAttachment]) -> Outcome {
        logger.error("Sending attachments ran out of time")
        let isConnectionLost = !chat.session.connection.isNetworkAvailable || !chat.isConnected
        let failure = ChatError.uploadFailed(fileNames: batch.filter(isInTray).map(\.fileName))
        return .failed(
            Self.alert(for: failure, isConnectionLost: isConnectionLost, in: batch),
            isConnectionLost: isConnectionLost
        )
    }

    func isInTray(_ file: PendingAttachment) -> Bool {
        chat.session.tray.items.contains { $0.id == file.id }
    }

    /// The files the chat kept, with the ids it gave them; ones cancelled meanwhile are not among them.
    func outcome(of uploaded: [UploadedAttachment], for files: [PendingAttachment]) -> Outcome {
        let ids = Dictionary(uniqueKeysWithValues: uploaded.compactMap { upload in
            upload.pendingId.map { ($0, upload.id) }
        })
        let kept = files.compactMap { file in
            ids[file.id].map { id in
                ChatAttachment(
                    id: id,
                    fileName: file.fileName,
                    fileSize: file.fileSize,
                    previewUri: file.isImage ? file.fileURL.absoluteString : nil,
                    localFileUri: file.fileURL.absoluteString,
                    mimeType: file.mimeType,
                    isImage: file.isImage
                )
            }
        }
        return kept.isEmpty ? .cancelled : .uploaded(kept)
    }

    static func alert(
        for failure: ChatError,
        isConnectionLost: Bool,
        in batch: [PendingAttachment]
    ) -> AttachmentAlert {
        if isConnectionLost {
            return .networkError
        }
        return switch failure {
            case let .uploadFailed(fileNames): .uploadFailed(fileName: fileNames.joined(separator: ", "))
            case let .attachFailed(fileName, _): .attachFailed(fileName: fileName)
            default: .attachFailed(fileName: batch.map(\.fileName).joined(separator: ", "))
        }
    }
}
