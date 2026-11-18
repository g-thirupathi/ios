import Foundation

enum AttachmentUploadState: String, Sendable {
    case ready = "Ready"
    case presigning = "Presigning"
    case uploading = "Uploading"
    case uploaded = "Uploaded"
    case sending = "Sending"
    case sent = "Sent"
    case detaching = "Detaching"
    case detached = "Detached"
    case error = "Error"
    case unknown = "Unknown"

    var isInProgress: Bool {
        [.presigning, .uploading, .sending].contains(self)
    }
}
