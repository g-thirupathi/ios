import Foundation
@preconcurrency import MessengerTransport
import OSLog

/// Tracks the attachments uploaded for the next message and keeps them in step with the SDK's pending message.
/// Owned by `GenesysChatRemoteDataSource`, which hands it the current client.
final class GenesysPendingAttachments {
    private struct Upload {
        let id: String
        let fileName: String
        let pendingId: PendingAttachment.ID?
        var isUploaded = false
        var isFailed = false
    }

    private static let clearTimeout: Duration = .seconds(2)
    private static let idleTimeout: TimeInterval = 60
    private static let pollInterval: Duration = .milliseconds(100)
    private static let detachPollInterval: Duration = .milliseconds(50)

    private var batch: [Upload] = []
    /// Tray items whose upload the user cancelled; kept until the upload call ends, as a file can be cancelled
    /// before the SDK has it.
    private var cancelled: Set<PendingAttachment.ID> = []
    private var generation = 0
    private var lastProgress = Date()
    private let logger = Logger(category: "GenesysPendingAttachments")

    func recordUpdate(id: String, state: AttachmentUploadState) {
        guard let index = batch.firstIndex(where: { $0.id == id }), !isCancelled(batch[index].pendingId) else { return }
        lastProgress = Date()
        switch state {
            case .uploaded:
                batch[index].isUploaded = true
            case .error:
                batch[index].isFailed = true
            case .detached where !batch[index].isUploaded:
                batch[index].isFailed = true
            default:
                break
        }
    }

    /// The tray item an SDK attachment of the current batch was uploaded for.
    func pendingId(forSdkId id: String) -> PendingAttachment.ID? {
        batch.first { $0.id == id }?.pendingId
    }

    /// Forgets the batch and ends what waits on it: the SDK clears its attachments when the transport closes, and
    /// a sent message takes its attachments with it.
    func reset() {
        batch.removeAll()
        generation += 1
    }

    /// Stops one file's upload for good; the others carry on and the file is left out of the result of `upload`.
    func cancel(pendingId: PendingAttachment.ID, using client: MessagingClient) {
        cancelled.insert(pendingId)
        if let upload = batch.first(where: { $0.pendingId == pendingId }) {
            detach([upload.id], using: client)
        }
    }

    /// Detaches what would still go out, e.g. after a failed upload or send, which the SDK would never confirm.
    func discardPending(using client: MessagingClient) async {
        let ids = outgoingIds(in: client)
        detach(ids, using: client)
        _ = await waitUntilNotOutgoing(ids, in: client, timeout: Self.clearTimeout)
        reset()
    }

    func prepareForUpload(using client: MessagingClient) async {
        await discardPending(using: client)
    }

    /// Uploads the files, which then run concurrently, and returns the ones that were not cancelled once every one is
    /// uploaded. If any upload fails or stalls, all of them are detached and the call throws.
    func upload(_ files: [AttachmentBytes], using client: MessagingClient) async throws -> [UploadedAttachment] {
        let startedGeneration = generation
        defer { cancelled.removeAll() }
        for file in files where !isCancelled(file.pendingId) {
            do {
                let attachmentId = try client.attach(
                    byteArray: file.bytes,
                    fileName: file.fileName,
                    uploadProgress: { @Sendable [weak self] _ in
                        DispatchQueue.main.async { self?.lastProgress = Date() }
                    }
                )
                batch.append(Upload(id: attachmentId, fileName: file.fileName, pendingId: file.pendingId))
                logger.info("Attached \(attachmentId.prefix(8)), SDK pending [\(self.summary(of: client))]")
            } catch {
                await discardPending(using: client)
                let failure = ChatSdkMapper.error(error)
                throw failure.isNotConnected ? failure : ChatError.attachFailed(fileName: file.fileName, cause: error)
            }
        }
        lastProgress = Date()
        try await waitForUploads(startedIn: startedGeneration, in: client)
        batch.removeAll { isCancelled($0.pendingId) }
        return batch.map { UploadedAttachment(id: $0.id, pendingId: $0.pendingId) }
    }

    /// Checks the uploaded attachments are still the ones the SDK will send.
    func prepareToSend(using client: MessagingClient) async throws {
        let sentIds = Set(batch.map(\.id))
        logger.info("Send: cached \(sentIds.sorted()), SDK pending [\(self.summary(of: client))]")

        if sentIds.isEmpty {
            await discardPending(using: client)
        } else {
            let staleIds = outgoingIds(in: client).subtracting(sentIds)
            if !staleIds.isEmpty {
                detach(staleIds, using: client)
                if await !waitUntilNotOutgoing(staleIds, in: client, timeout: Self.clearTimeout) {
                    logger.error("Stale \(staleIds.sorted()) still outgoing, SDK pending [\(self.summary(of: client))]")
                    await discardPending(using: client)
                    throw ChatError.staleAttachments
                }
            }
            guard batch.allSatisfy(\.isUploaded) else {
                await discardPending(using: client)
                throw ChatError.staleAttachments
            }
        }
    }
}

private extension GenesysPendingAttachments {
    func isCancelled(_ pendingId: PendingAttachment.ID?) -> Bool {
        pendingId.map { cancelled.contains($0) } ?? false
    }

    func summary(of client: MessagingClient) -> String {
        client.pendingMessage.attachments
            .map { "\($0.key.prefix(8)) \($0.value.fileName ?? "?") \(ChatSdkMapper.uploadState($0.value.state))" }
            .sorted()
            .joined(separator: ", ")
    }

    /// Pending attachments that would go out with the next message. The SDK's pending message also keeps entries
    /// that never will (refreshed, detached and failed ones) until the next message is prepared, so waiting for
    /// every pending entry to clear would stall every attach. Sent ones stay in it as `sending` until the chat
    /// confirms them; the SDK does not send them again, and detaching one would drop its confirmation and link.
    func outgoingIds(in client: MessagingClient) -> Set<String> {
        let outgoing: Set<AttachmentUploadState> = [.presigning, .uploading, .uploaded]
        let pending = client.pendingMessage.attachments
        return Set(pending.filter { outgoing.contains(ChatSdkMapper.uploadState($0.value.state)) }.keys)
    }

    /// Only ids that are still outgoing can be detached; the SDK throws for the others.
    func detach(_ ids: Set<String>, using client: MessagingClient) {
        for id in ids {
            do {
                try client.detach(attachmentId: id)
            } catch {
                logger.error("Detach \(id.prefix(8)) failed: \(error)")
            }
        }
    }

    func waitUntilNotOutgoing(_ ids: Set<String>, in client: MessagingClient, timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !outgoingIds(in: client).isDisjoint(with: ids) {
            if ContinuousClock.now > deadline {
                return false
            }
            do {
                try await Task.sleep(for: Self.detachPollInterval)
            } catch {
                return false
            }
        }
        return true
    }

    /// Waits until every attachment is uploaded, failing as soon as one errors or none has made progress for
    /// `idleTimeout`, or as soon as the transport is lost, which resets the batch.
    func waitForUploads(startedIn startedGeneration: Int, in client: MessagingClient) async throws {
        while true {
            guard generation == startedGeneration else {
                throw ChatError.notConnected
            }
            let pending = batch.filter { !$0.isUploaded && !isCancelled($0.pendingId) }
            if pending.isEmpty {
                return
            }
            let failed = pending.filter(\.isFailed)
            let isStalled = Date().timeIntervalSince(lastProgress) > Self.idleTimeout
            if !failed.isEmpty || isStalled {
                logger.error("Upload failed: \(failed.count) errored, stalled: \(isStalled), \(pending.count) pending")
                let fileNames = (failed.isEmpty ? pending : failed).map(\.fileName)
                await discardPending(using: client)
                throw ChatError.uploadFailed(fileNames: fileNames)
            }
            do {
                try await Task.sleep(for: Self.pollInterval)
            } catch {
                await discardPending(using: client)
                throw error
            }
        }
    }
}
