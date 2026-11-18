import Foundation

extension ChatConnection {
    mutating func apply(isConfigured: Bool, connected: Bool, conversationClearEnabled: Bool) {
        isConversationClearEnabled = conversationClearEnabled
        self.isConfigured = isConfigured
        isReadOnly = false
        if isConfigured {
            status = connected ? .connected : .reconnecting
            error = nil
        } else if isNetworkAvailable {
            status = .reconnecting
        }
    }

    mutating func applySdkNetworkAvailability(_ isAvailable: Bool) {
        isSdkNetworkAvailable = isAvailable
    }

    /// The chat is closed but its session is still open to read.
    mutating func markReadOnly() {
        isConfigured = true
        isReadOnly = true
        status = .connected
        error = nil
    }

    /// The conversation was cleared, which also ends its session.
    mutating func markCleared() {
        isConfigured = false
        isReadOnly = true
    }

    mutating func leaveReadOnly() {
        isReadOnly = false
    }

    /// The next connect attempt initializes the session again.
    mutating func invalidateSession() {
        isSessionInitialized = false
    }

    /// The chat's own verdict that it cannot reach the network is dropped too: this attempt decides it again.
    mutating func prepareRetry() {
        isSessionInitialized = false
        isSdkNetworkAvailable = true
        error = nil
        status = .connecting
    }

    mutating func beginConnecting() {
        isSessionInitialized = true
        status = .connecting
        error = nil
    }

    mutating func markOffline() {
        status = .offline
    }

    /// A restart clears the last connection error.
    mutating func markReconnecting() {
        status = .reconnecting
        error = nil
    }

    /// Waiting for the transport before an upload keeps the last connection error.
    mutating func showReconnecting() {
        status = .reconnecting
    }

    /// A chat that is connected has reached the network, so an earlier verdict that it could not is out of date.
    mutating func markConnected() {
        status = .connected
        isSdkNetworkAvailable = true
    }

    mutating func markBackgrounded(at date: Date) {
        backgroundedAt = date
    }

    mutating func markReturned() {
        backgroundedAt = nil
    }

    mutating func markConnectionLost() {
        status = isNetworkAvailable ? .reconnecting : .offline
    }

    mutating func fail(_ error: ChatConnectionError) {
        status = .error
        self.error = error
    }

    /// The status follows the network only while the chat screen shows it.
    mutating func applyNetworkChange(isConnected: Bool, isScreenActive: Bool) {
        isNetworkAvailable = isConnected
        if isConnected {
            isSdkNetworkAvailable = true
        }
        guard isScreenActive else { return }
        if !isConnected {
            status = .offline
        } else if status == .offline {
            status = .reconnecting
        }
    }
}
