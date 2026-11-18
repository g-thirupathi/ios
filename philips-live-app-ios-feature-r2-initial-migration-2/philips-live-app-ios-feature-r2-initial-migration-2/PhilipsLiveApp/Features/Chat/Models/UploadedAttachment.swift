import Foundation

/// A file the chat has taken, with the tray item it was uploaded for. Nil for files with none (a retry).
nonisolated struct UploadedAttachment: Sendable {
    let id: String
    let pendingId: PendingAttachment.ID?
}
