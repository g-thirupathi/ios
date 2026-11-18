import Foundation

enum ChatTimeout {
    /// How long an action gives a chat that is reconnecting to come back before it acts without it.
    static let reconnectGrace: TimeInterval = 10
}
