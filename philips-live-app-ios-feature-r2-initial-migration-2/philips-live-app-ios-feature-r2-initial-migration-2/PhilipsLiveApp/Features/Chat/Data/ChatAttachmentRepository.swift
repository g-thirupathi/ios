import Foundation

protocol ChatAttachmentRepository: AnyObject {
    /// Keeps a private copy of a picked file, so it can be uploaded later and shown as a preview after sending.
    func store(_ data: Data, fileName: String, maxSize: Int) async throws -> StoredAttachmentFile
    func importFile(at url: URL, fileName: String, maxSize: Int) async throws -> StoredAttachmentFile
    /// The photo as it is when its type is one of `mimeTypes`, otherwise as JPEG.
    func compatiblePhoto(_ data: Data, keeping mimeTypes: Set<String>) async -> CompatibleImage
    func data(at url: URL) async throws -> Data
    func remove(_ url: URL) async
    /// Deletes the files of earlier launches that no saved message refers to by `urls`.
    func removeFiles(except urls: Set<URL>) async
    /// Remembers attachments sent in this session, so the SDK's echo of the message gets its local previews back.
    func registerSent(_ attachments: [ChatAttachment])
    /// Gives the attachments of an own message, as the SDK echoes it, the local previews and files of the files sent
    /// in this session.
    func applyingPreviews(to message: ChatMessage) -> ChatMessage
    /// Saved previews and local files are absolute paths, and the app container path changes on reinstall or update.
    func resolvingLocalFiles(in messages: [ChatMessage]) -> [ChatMessage]
    func isDisclaimerAccepted() -> Bool
    func acceptDisclaimer()
}

/// The files of chat attachments, their local previews and the attachment disclaimer.
final class DefaultChatAttachmentRepository: ChatAttachmentRepository {
    private let files: ChatAttachmentLocalDataSource
    private let local: ChatLocalDataSource
    private let images: ImageConversionProvider
    private var sentPreviews: [String: ChatAttachment] = [:]

    init(files: ChatAttachmentLocalDataSource, local: ChatLocalDataSource, images: ImageConversionProvider) {
        self.files = files
        self.local = local
        self.images = images
    }

    func store(_ data: Data, fileName: String, maxSize: Int) async throws -> StoredAttachmentFile {
        try await files.store(data, fileName: fileName, maxSize: maxSize)
    }

    func importFile(at url: URL, fileName: String, maxSize: Int) async throws -> StoredAttachmentFile {
        try await files.importFile(at: url, fileName: fileName, maxSize: maxSize)
    }

    func compatiblePhoto(_ data: Data, keeping mimeTypes: Set<String>) async -> CompatibleImage {
        await images.compatibleImage(data, keeping: mimeTypes)
    }

    func data(at url: URL) async throws -> Data {
        try await files.data(at: url)
    }

    func remove(_ url: URL) async {
        await files.remove(url)
    }

    func removeFiles(except urls: Set<URL>) async {
        await files.removeFiles(except: urls)
    }

    func registerSent(_ attachments: [ChatAttachment]) {
        for attachment in attachments {
            if let id = attachment.id {
                sentPreviews[id] = attachment
            }
        }
    }

    func applyingPreviews(to message: ChatMessage) -> ChatMessage {
        guard message.kind == .message, message.isFromUser, !message.attachments.isEmpty else { return message }
        var message = message
        message.attachments = message.attachments.map { attachment in
            guard let id = attachment.id, let preview = sentPreviews[id] else { return attachment }
            var merged = attachment
            merged.previewUri = attachment.previewUri ?? preview.previewUri
            merged.localFileUri = attachment.localFileUri ?? preview.localFileUri
            merged.mimeType = attachment.mimeType ?? preview.mimeType
            merged.isImage = attachment.isImage || preview.isImage
            merged.fileSize = attachment.fileSize ?? preview.fileSize
            return merged
        }
        return message
    }

    func resolvingLocalFiles(in messages: [ChatMessage]) -> [ChatMessage] {
        messages.map { message in
            var message = message
            message.attachments = message.attachments.map { attachment in
                var attachment = attachment
                attachment.previewUri = attachment.previewUri.flatMap(files.resolvedLocalUri)
                attachment.localFileUri = attachment.localFileUri.flatMap(files.resolvedLocalUri)
                return attachment
            }
            return message
        }
    }

    func isDisclaimerAccepted() -> Bool {
        local.isAttachmentDisclaimerAccepted()
    }

    func acceptDisclaimer() {
        local.acceptAttachmentDisclaimer()
    }
}
