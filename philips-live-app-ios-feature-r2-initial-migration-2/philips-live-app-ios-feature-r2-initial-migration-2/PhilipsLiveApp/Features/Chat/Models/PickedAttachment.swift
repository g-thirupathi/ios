import Foundation

/// A picked file before it is checked and copied: its name and type, and where its bytes are.
struct PickedAttachment {
    enum Content {
        case data(Data)
        case file(URL)
    }

    let fileName: String
    let mimeType: String?
    let content: Content
}
