import Foundation

enum ChatConnectionError: Equatable {
    case missingConfiguration
    /// Philips cannot offer the chat now, and trying again does not change that: the deployment is switched off or
    /// refuses the app.
    case unavailable
    case connectionFailed
}
