import Foundation
@preconcurrency import MessengerTransport

/// Requests fresh links to received attachments, one at a time, and hands each over once the SDK reports it.
/// Owned by `GenesysChatRemoteDataSource`, which hands it the current client.
final class GenesysAttachmentLinks {
    /// `token` tells a request apart from another one for the same attachment.
    private struct PendingLink {
        let token: UUID
        let attachmentId: String
        let continuation: CheckedContinuation<URL, Error>
    }

    private var pending: PendingLink?

    /// A new request cancels the previous one, and a cancelled request throws `CancellationError` at once.
    func url(forId id: String, using client: MessagingClient) async throws -> URL {
        resolve(with: .failure(CancellationError()))
        let token = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = PendingLink(token: token, attachmentId: id, continuation: continuation)
                do {
                    try client.refreshAttachmentUrl(attachmentId: id)
                } catch {
                    resolve(with: .failure(ChatSdkMapper.error(error)))
                }
            }
        } onCancel: {
            // Runs after the request is pending, as both run on the main actor.
            Task { @MainActor [weak self] in
                self?.resolve(where: { $0.token == token }, with: .failure(CancellationError()))
            }
        }
    }

    func recordUpdate(id: String, state: AttachmentUploadState, downloadUrl: String?) {
        if let url = downloadUrl.flatMap(URL.init(string:)) {
            resolve(where: { $0.attachmentId == id }, with: .success(url))
        } else if state == .error {
            resolve(where: { $0.attachmentId == id }, with: .failure(ChatError.notConnected))
        }
    }

    /// Fails the waiting request, as the client it was asked on is gone.
    func reset() {
        resolve(with: .failure(ChatError.notConnected))
    }

    private func resolve(where matches: (PendingLink) -> Bool = { _ in true }, with result: Result<URL, Error>) {
        guard let link = pending, matches(link) else { return }
        pending = nil
        link.continuation.resume(with: result)
    }
}
