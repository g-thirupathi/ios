import Foundation

/// The chat's connection as the app sees it: the SDK session, the network and the last connection error.
struct ChatConnection: Equatable {
    var isConfigured = false
    var isReadOnly = false
    var isConversationClearEnabled = false
    var isSessionInitialized = false
    var isNetworkAvailable = true
    var isSdkNetworkAvailable = true
    var status: ChatConnectionStatus = .connecting
    var error: ChatConnectionError?
    /// When the app left the foreground, until it comes back.
    var backgroundedAt: Date?

    /// The OS path monitor can report a usable path while there is no internet, so the SDK's own verdict counts too.
    var hasConnectivity: Bool {
        isNetworkAvailable && isSdkNetworkAvailable
    }

    /// The chat gave up and the user can try again.
    var isFailed: Bool {
        status == .error && error == .connectionFailed
    }

    /// The chat cannot be offered, however often it is tried.
    var isUnavailable: Bool {
        error == .missingConfiguration || error == .unavailable
    }
}
