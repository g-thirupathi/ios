import Foundation
@preconcurrency import MessengerTransport

struct AttachmentBytes {
    let fileName: String
    let bytes: KotlinByteArray
    let pendingId: PendingAttachment.ID?
}
