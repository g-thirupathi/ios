import Foundation
import UniformTypeIdentifiers

extension ChatAttachment {
    static let maxCount = 5
    private static let bytesPerMegabyte = 1024 * 1024
    static let maxFileSize = 10 * bytesPerMegabyte

    /// Photos in other formats (e.g. HEIC) are sent as JPEG.
    static let compatibleImageMimeTypes: Set<String> = [
        "image/jpeg", "image/png", "image/gif", "image/bmp", "image/tiff",
    ]

    private static let supportedMimeTypes: Set<String> = [
        "application/pdf", "image/bmp", "image/gif", "image/jpeg", "image/jpg", "image/svg+xml", "image/tiff",
        "image/png", "text/plain", "video/mpeg", "video/mpg", "audio/wav", "audio/wave", "video/mp4", "audio/mp4",
        "video/webm", "audio/webm", "video/quicktime", "audio/mpeg3", "audio/mp3", "audio/mpg", "audio/mpeg",
        "application/xml", "text/xml", "text/json", "text/x-java-source",
    ]

    private static let supportedExtensionPattern =
        #"\.(bmp|gif|jpe?g|json|java|m4a|mov|mp3|mp4|mpeg|mpg|pdf|png|svg|tiff?|txt|wav|webm|xml)$"#
    static let jpegMimeType = "image/jpeg"
    private static let jpegExtension = ".jpg"
    private static let cameraPhotoPrefix = "photo_"
    private static let pickedPhotoPrefix = "IMG_"
    private static let imageMimePrefix = "image/"
    private static let videoMimePrefix = "video/"
    private static let heicExtensionPattern = #"\.(heic|heif)$"#
    private static let imageExtensionPattern = #"\.(avif|gif|heic|heif|jpe?g|png|webp)$"#

    /// A known MIME type is trusted, other images and videos are rejected, and otherwise the extension decides.
    static func isSupported(fileName: String, mimeType: String?) -> Bool {
        if let mimeType = mimeType?.lowercased() {
            if supportedMimeTypes.contains(mimeType) {
                return true
            }
            if mimeType.hasPrefix(imageMimePrefix) || mimeType.hasPrefix(videoMimePrefix) {
                return false
            }
        }
        return fileName.matches(supportedExtensionPattern)
    }

    static func normalizedFileName(_ fileName: String, mimeType: String?) -> String {
        guard mimeType?.lowercased() == jpegMimeType,
              let range = fileName.range(of: heicExtensionPattern, options: [.regularExpression, .caseInsensitive])
        else { return fileName }
        return fileName.replacingCharacters(in: range, with: jpegExtension)
    }

    static func cameraPhotoFileName(at date: Date) -> String {
        "\(cameraPhotoPrefix)\(date.epochMilliseconds)\(jpegExtension)"
    }

    /// Photos picked together share the time they were picked and are told apart by their position.
    static func pickedPhotoBaseName(at date: Date, index: Int) -> String {
        "\(pickedPhotoPrefix)\(date.epochMilliseconds)_\(index + 1)"
    }

    static func isImage(fileName: String, mimeType: String?) -> Bool {
        mimeType?.lowercased().hasPrefix(imageMimePrefix) == true || fileName.matches(imageExtensionPattern)
    }

    static func mimeType(forFileName fileName: String) -> String? {
        UTType(filenameExtension: (fileName as NSString).pathExtension)?.preferredMIMEType
    }
}
