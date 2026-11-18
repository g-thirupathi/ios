import Foundation

nonisolated struct AttachmentUpload: Sendable {
    let data: Data
    let fileName: String
    /// The tray item the file comes from, so its upload updates reach that item. Nil for files with none (a retry).
    let pendingId: PendingAttachment.ID?
}
