import Foundation

protocol OpenAttachmentUseCase {
    /// The link to open a received attachment: a fresh one for attachments with an id, as the chat's links expire.
    /// When the chat cannot give one, the link the attachment came with.
    func execute(_ attachment: ChatAttachment) async throws -> URL
}

/// A link that does not arrive within `linkTimeout` fails as not connected. A chat that is only reconnecting gets
/// `ChatTimeout.reconnectGrace` to come back first. The link an attachment came with expires after about ten minutes,
/// so it is only the fallback.
struct DefaultOpenAttachmentUseCase: OpenAttachmentUseCase {
    private static let linkTimeout: Duration = .seconds(15)

    private let chat: ChatRepository
    private let waitForTransport: WaitForTransportUseCase

    init(chat: ChatRepository, waitForTransport: WaitForTransportUseCase) {
        self.chat = chat
        self.waitForTransport = waitForTransport
    }

    func execute(_ attachment: ChatAttachment) async throws -> URL {
        let storedURL = attachment.downloadUrl.flatMap(URL.init(string:))
        guard let id = attachment.id else {
            return try fallback(storedURL)
        }
        if isReconnecting {
            _ = await waitForTransport.execute(timeout: ChatTimeout.reconnectGrace)
        }
        guard chat.isConnected else {
            return try fallback(storedURL)
        }
        let request = Task { try await chat.attachmentURL(forId: id) }
        let timeout = Task { () -> Bool in
            do {
                try await Task.sleep(for: Self.linkTimeout)
            } catch {
                return false
            }
            request.cancel()
            return true
        }
        do {
            let url = try await request.value
            timeout.cancel()
            return url
        } catch {
            timeout.cancel()
            let timedOut = await timeout.value
            // A request cancelled by a newer one keeps its `CancellationError`.
            if let storedURL, timedOut || !(error is CancellationError) {
                return storedURL
            }
            throw timedOut ? ChatError.notConnected : error
        }
    }

    /// The chat is not read-only and the network is up, so it is expected back on its own.
    private var isReconnecting: Bool {
        let connection = chat.session.connection
        return !chat.isConnected && connection.isNetworkAvailable && !connection.isReadOnly
    }

    private func fallback(_ storedURL: URL?) throws -> URL {
        guard let storedURL else {
            throw ChatError.notConnected
        }
        return storedURL
    }
}
