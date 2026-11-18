import Foundation

/// The parts of the chat session that survive a relaunch.
struct PersistedChat {
    var messages: [ChatMessage] = []
    var oldMessages: [ChatMessage] = []
    var closedAt: Date?
    var previousClosedAt: Date?
}
