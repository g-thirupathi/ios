import Foundation

extension ChatAttachment {
    func isSame(as other: ChatAttachment) -> Bool {
        if let id, let otherId = other.id {
            return id == otherId
        }
        return fileName == other.fileName
    }
}
