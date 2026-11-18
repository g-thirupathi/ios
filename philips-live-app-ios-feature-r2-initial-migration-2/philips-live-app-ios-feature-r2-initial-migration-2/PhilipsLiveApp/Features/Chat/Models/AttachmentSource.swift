import Foundation

enum AttachmentSource {
    case data(Data, fileName: String, mimeType: String?)
    case file(URL)
    /// From the photo library; named `<baseName>.<extension>` once it is in a format Genesys accepts.
    case photo(Data, baseName: String)
}
