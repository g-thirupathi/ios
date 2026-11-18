protocol RemoveAttachmentUseCase {
    func execute(id: PendingAttachment.ID)
}

/// Takes a picked file out of the tray and deletes its private copy. While the tray is being sent this cancels the
/// upload of that file only; the others carry on.
struct DefaultRemoveAttachmentUseCase: RemoveAttachmentUseCase {
    private let chat: ChatRepository
    private let attachments: ChatAttachmentRepository

    init(chat: ChatRepository, attachments: ChatAttachmentRepository) {
        self.chat = chat
        self.attachments = attachments
    }

    func execute(id: PendingAttachment.ID) {
        guard let attachment = chat.session.tray.items.first(where: { $0.id == id }) else { return }
        if chat.session.tray.isSending {
            chat.cancelUpload(pendingId: id)
        }
        chat.update { $0.tray.remove(id: id) }
        Task { await attachments.remove(attachment.fileURL) }
    }
}
