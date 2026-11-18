import Foundation

/// A picked file waiting in the preview bar until it is sent with the next message.
struct PendingAttachment: Identifiable, Hashable {
    /// Declared so nonisolated types can name it without the main-actor `Identifiable` conformance.
    typealias ID = UUID // swiftlint:disable:this type_name

    let id = ID()
    let fileName: String
    let fileSize: Int
    let mimeType: String?
    let fileURL: URL
    let digest: String
    var state: AttachmentUploadState = .ready

    var isImage: Bool {
        ChatAttachment.isImage(fileName: fileName, mimeType: mimeType)
    }
}
