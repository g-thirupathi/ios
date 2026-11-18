import Foundation

struct ChatAttachment: Codable, Equatable {
    var id: String?
    var fileName: String
    var fileSize: Int?
    /// The local image shown as the thumbnail; images only.
    var previewUri: String?
    /// The local copy of an own attachment of any type, which a failed message is sent again from.
    var localFileUri: String?
    var mimeType: String?
    var isImage = false
    var downloadUrl: String?
}

extension ChatAttachment {
    private enum CodingKeys: String, CodingKey {
        case id, fileName, fileSize, previewUri, localFileUri, mimeType, isImage, downloadUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        fileSize = try container.decodeIfPresent(Int.self, forKey: .fileSize)
        previewUri = try container.decodeIfPresent(String.self, forKey: .previewUri)
        localFileUri = try container.decodeIfPresent(String.self, forKey: .localFileUri)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        isImage = try container.decodeIfPresent(Bool.self, forKey: .isImage) ?? false
        downloadUrl = try container.decodeIfPresent(String.self, forKey: .downloadUrl)
    }
}
