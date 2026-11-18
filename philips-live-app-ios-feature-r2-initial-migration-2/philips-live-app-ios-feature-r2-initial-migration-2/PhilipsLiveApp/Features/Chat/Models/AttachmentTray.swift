import Foundation

/// The files picked for the next message, while they wait and while they are sent.
struct AttachmentTray: Equatable {
    var items: [PendingAttachment] = []
    var isSending = false
    var alert: AttachmentAlert?
}
