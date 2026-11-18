import Foundation
import UniformTypeIdentifiers

extension ChatAttachment {
    static let pickerContentTypes: [UTType] = [
        .pdf, .image, .plainText, .movie, .audio, .json, .xml, .sourceCode,
    ]

    /// Kilobytes or megabytes in 1024-byte steps, written by Foundation in the selected language.
    static func formattedSize(_ bytes: Int, locale: Locale) -> String {
        Int64(bytes).formatted(.byteCount(style: .memory, allowedUnits: [.kb, .mb]).locale(locale))
    }
}
