import Foundation
import OSLog

protocol ResendMessageUseCase {
    /// Sends a failed own message again, after the user tapped retry.
    func execute(_ message: ChatMessage)
}

struct DefaultResendMessageUseCase: ResendMessageUseCase {
    private let chat: ChatRepository
    private let attachments: ChatAttachmentRepository
    private let deliver: DeliverTextMessageUseCase
    private let prepareTransport: PrepareAttachmentTransportUseCase
    private let watchDelivery: WatchDeliveryUseCase
    private let verifyDelivered: VerifyMessageDeliveredUseCase
    private let logger = Logger(category: "ResendMessageUseCase")

    init(
        chat: ChatRepository,
        attachments: ChatAttachmentRepository,
        deliver: DeliverTextMessageUseCase,
        prepareTransport: PrepareAttachmentTransportUseCase,
        watchDelivery: WatchDeliveryUseCase,
        verifyDelivered: VerifyMessageDeliveredUseCase
    ) {
        self.chat = chat
        self.attachments = attachments
        self.deliver = deliver
        self.prepareTransport = prepareTransport
        self.watchDelivery = watchDelivery
        self.verifyDelivered = verifyDelivered
    }

    func execute(_ message: ChatMessage) {
        guard message.isFromUser, message.kind == .message else { return }
        var retried: ChatMessage?
        let newLocalId = UUID().uuidString
        chat.update { retried = $0.conversation.markSendingAgain(message, newLocalId: newLocalId) }
        guard let retried else { return }
        if retried.attachments.isEmpty {
            chat.inSendOrder { await deliver.execute(retried, restart: false, replacing: message) }
        } else {
            chat.inSendOrder { await handOverAgain(retried, replacing: message) }
        }
    }

    /// Retried from its local files: ids from an earlier attempt are gone once the chat has taken the message, and
    /// Genesys may have expired them. The chat can end while the retry waits for the connection or reads the files;
    /// that fails the message and moves it to the earlier conversation, so nothing is uploaded for it then. Nothing is
    /// uploaded either if the chat turns out to have the failed message already.
    private func handOverAgain(_ message: ChatMessage, replacing failed: ChatMessage) async {
        guard let localId = message.localId, isAwaitingDelivery(message) else { return }
        do {
            guard chat.session.connection.isNetworkAvailable, await prepareTransport.execute() else {
                throw ChatError.notConnected
            }
            guard isAwaitingDelivery(message) else { return }
            if await verifyDelivered.execute(failed: failed, retried: message) {
                return
            }
            var uploads: [AttachmentUpload] = []
            for attachment in message.attachments {
                guard let url = attachment.localFileUri.flatMap(URL.init(string:)) else {
                    throw ChatError.attachFailed(
                        fileName: attachment.fileName,
                        cause: CocoaError(.fileNoSuchFile)
                    )
                }
                let data = try await attachments.data(at: url)
                uploads.append(AttachmentUpload(data: data, fileName: attachment.fileName, pendingId: nil))
            }
            guard isAwaitingDelivery(message) else { return }
            let ids = try await chat.attach(uploads).map(\.id)
            let refreshed = zip(message.attachments, ids).map { attachment, id -> ChatAttachment in
                var copy = attachment
                copy.id = id
                return copy
            }
            attachments.registerSent(refreshed)
            chat.update { $0.conversation.replaceAttachments(localId: localId, with: refreshed) }
            try await chat.send(message.text, localId: localId)
            watchDelivery.execute(message)
        } catch {
            logger.error("Retry with attachments failed: \(error)")
            chat.update { $0.conversation.markNotSent(message) }
        }
    }

    private func isAwaitingDelivery(_ message: ChatMessage) -> Bool {
        chat.session.conversation.isAwaitingDelivery(message)
    }
}
