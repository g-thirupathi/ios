import Foundation

nonisolated struct StoredAttachmentFile: Sendable, Equatable {
    let url: URL
    let size: Int
    let digest: String
}
