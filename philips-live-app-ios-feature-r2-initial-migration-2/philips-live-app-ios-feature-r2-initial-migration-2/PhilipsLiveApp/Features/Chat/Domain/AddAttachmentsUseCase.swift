import Foundation
import OSLog

protocol AddAttachmentsUseCase {
    func execute(_ sources: [AttachmentSource]) async -> AttachmentAddResult
}

/// Adds picked files to the tray for the next message: checks each file, keeps a private copy and rejects
/// unsupported, empty, oversized and duplicate ones.
struct DefaultAddAttachmentsUseCase: AddAttachmentsUseCase {
    private let chat: ChatRepository
    private let attachments: ChatAttachmentRepository
    private let logger = Logger(category: "AddAttachmentsUseCase")

    init(chat: ChatRepository, attachments: ChatAttachmentRepository) {
        self.chat = chat
        self.attachments = attachments
    }

    func execute(_ sources: [AttachmentSource]) async -> AttachmentAddResult {
        var result = AttachmentAddResult()
        let remaining = ChatAttachment.maxCount - chat.session.tray.items.count
        guard remaining > 0 else {
            result.alert = .limitReached
            return result
        }
        if sources.count > remaining {
            result.alert = .onlyFilesAdded(count: remaining)
        }
        var problems = Set<AttachmentAlert>()
        for source in sources.prefix(remaining) {
            if let problem = await add(source, result: &result) {
                problems.insert(problem)
            }
        }
        result.alert = result.alert ?? [.duplicates, .unsupported, .invalid, .readFailed]
            .first(where: problems.contains)
        return result
    }
}

private extension DefaultAddAttachmentsUseCase {
    func add(_ source: AttachmentSource, result: inout AttachmentAddResult) async -> AttachmentAlert? {
        let picked = await pick(source)
        let mimeType = picked.mimeType
        let fileName = ChatAttachment.normalizedFileName(picked.fileName, mimeType: mimeType)
        guard ChatAttachment.isSupported(fileName: fileName, mimeType: mimeType) else {
            logger.error("Attachment \(fileName) unsupported (mime: \(mimeType ?? "nil"))")
            return .unsupported
        }

        let stored: StoredAttachmentFile
        do {
            stored = switch picked.content {
                case let .data(data):
                    try await attachments.store(data, fileName: fileName, maxSize: ChatAttachment.maxFileSize)
                case let .file(url):
                    try await attachments.importFile(at: url, fileName: fileName, maxSize: ChatAttachment.maxFileSize)
            }
        } catch ChatAttachmentFileError.tooLarge {
            logger.error("Attachment \(fileName) is too large")
            result.hasOversizedFile = true
            return nil
        } catch ChatAttachmentFileError.empty {
            logger.error("Attachment \(fileName) is empty")
            return .invalid
        } catch {
            logger.error("Reading attachment \(fileName) failed: \(error)")
            return .readFailed
        }

        let pending = chat.session.tray.items
        let isDuplicate = pending.contains {
            $0.digest == stored.digest || ($0.fileName == fileName && $0.fileSize == stored.size)
        }
        guard !isDuplicate, pending.count < ChatAttachment.maxCount else {
            logger.error("Attachment \(fileName) skipped (duplicate: \(isDuplicate))")
            await attachments.remove(stored.url)
            return isDuplicate ? .duplicates : nil
        }
        chat.update {
            $0.tray.add(PendingAttachment(
                fileName: fileName,
                fileSize: stored.size,
                mimeType: mimeType,
                fileURL: stored.url,
                digest: stored.digest
            ))
        }
        return nil
    }

    func pick(_ source: AttachmentSource) async -> PickedAttachment {
        switch source {
            case let .data(data, fileName, mimeType):
                return PickedAttachment(fileName: fileName, mimeType: mimeType, content: .data(data))
            case let .photo(data, baseName):
                let image = await attachments.compatiblePhoto(data, keeping: ChatAttachment.compatibleImageMimeTypes)
                return PickedAttachment(
                    fileName: "\(baseName).\(image.fileExtension)",
                    mimeType: image.mimeType,
                    content: .data(image.data)
                )
            case let .file(url):
                let fileName = url.lastPathComponent
                return PickedAttachment(
                    fileName: fileName,
                    mimeType: ChatAttachment.mimeType(forFileName: fileName),
                    content: .file(url)
                )
        }
    }
}
