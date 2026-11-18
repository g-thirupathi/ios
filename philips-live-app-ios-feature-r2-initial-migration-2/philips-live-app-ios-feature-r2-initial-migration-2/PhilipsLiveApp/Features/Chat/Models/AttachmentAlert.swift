import Foundation

enum AttachmentAlert: Hashable {
    case limitReached
    case onlyFilesAdded(count: Int)
    case duplicates
    case unsupported
    case invalid
    case readFailed
    case pickPhotoFailed
    case pickFileFailed
    case takePhotoFailed
    case cameraUnavailable
    case cameraPermissionDenied
    case networkError
    case chatUnavailable
    case attachFailed(fileName: String)
    case uploadFailed(fileName: String)
}
