import Foundation

enum ChatError: Error {
    case notConfigured
    case notConnected
    case missingConfiguration
    case unavailable
    case staleAttachments
    case conversationNotCleared
    case attachFailed(fileName: String, cause: Error)
    case uploadFailed(fileNames: [String])
    case sdk(Error)

    init(classifying error: Error) {
        self = error as? ChatError ?? .sdk(error)
    }

    var isNotConfigured: Bool {
        switch self {
            case .notConfigured, .missingConfiguration: true
            default: false
        }
    }

    var isNotConnected: Bool {
        if case .notConnected = self {
            return true
        }
        return isNotConfigured
    }

    /// What the connection says about this failure to the user.
    var connectionError: ChatConnectionError {
        switch self {
            case .missingConfiguration: .missingConfiguration
            case .unavailable: .unavailable
            default: .connectionFailed
        }
    }
}
