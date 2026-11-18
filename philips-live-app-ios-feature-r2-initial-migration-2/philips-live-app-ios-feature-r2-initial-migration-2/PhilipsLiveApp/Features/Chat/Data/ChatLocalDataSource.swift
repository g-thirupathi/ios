import Foundation
import OSLog

protocol ChatLocalDataSource {
    /// Throws when the Keychain cannot be read, so the saved chat is not mistaken for an empty one and overwritten.
    /// Saved data that is read but cannot be decoded is lost for good, so it is dropped: a message that fails is
    /// skipped, and a list that cannot be parsed counts as empty.
    func load() throws -> PersistedChat
    func saveMessages(_ messages: [ChatMessage])
    func saveOldMessages(_ messages: [ChatMessage])
    func saveClosedAt(_ date: Date?)
    func savePreviousClosedAt(_ date: Date?)
    func isAttachmentDisclaimerAccepted() -> Bool
    func acceptAttachmentDisclaimer()
}

/// Same Keychain keys and JSON as R1's `chatStorage.ts`.
struct KeychainChatLocalDataSource: ChatLocalDataSource {
    private enum Key {
        static let messages = "chat_messages"
        static let oldMessages = "chat_old_messages"
        static let closedAt = "chat_closed_at"
        static let previousClosedAt = "chat_previous_closed_at"
        static let messagesTimestamp = "chat_messages_timestamp"
        static let attachmentDisclaimerAccepted = "attachment_disclaimer_accepted"
    }

    /// Stands in for a saved message that failed to decode, to move past it whatever its JSON value.
    private struct UnreadableMessage: Decodable {
        init(from _: Decoder) {}
    }

    /// Decodes the saved array message by message, so one that fails costs only itself.
    private struct SavedMessages: Decodable {
        let messages: [ChatMessage]
        let failures: [Error]

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var messages: [ChatMessage] = []
            var failures: [Error] = []
            while !container.isAtEnd {
                do {
                    try messages.append(container.decode(ChatMessage.self))
                } catch {
                    failures.append(error)
                    // A failed decode leaves the container on the same element, so it is consumed to move on.
                    if try !container.decodeNil() {
                        _ = try container.decode(UnreadableMessage.self)
                    }
                }
            }
            self.messages = messages
            self.failures = failures
        }
    }

    private static let retention: TimeInterval = 30 * 24 * 60 * 60

    private let preferences: PreferencesLocalDataSource
    private let now: () -> Date
    private let logger = Logger(category: "ChatLocalDataSource")

    init(preferences: PreferencesLocalDataSource, now: @escaping () -> Date = Date.init) {
        self.preferences = preferences
        self.now = now
    }

    func load() throws -> PersistedChat {
        if let savedAt = try date(forKey: Key.messagesTimestamp),
           now().timeIntervalSince(savedAt) > Self.retention
        {
            clearAll()
            return PersistedChat()
        }
        return try PersistedChat(
            messages: messages(forKey: Key.messages),
            oldMessages: messages(forKey: Key.oldMessages),
            closedAt: date(forKey: Key.closedAt),
            previousClosedAt: date(forKey: Key.previousClosedAt)
        )
    }

    /// When the messages cannot be encoded the saved ones are kept, rather than replaced by nothing.
    func saveMessages(_ messages: [ChatMessage]) {
        guard let json = encode(messages) else { return }
        write(json, Key.messages)
        write(now().epochMilliseconds, Key.messagesTimestamp)
    }

    func saveOldMessages(_ messages: [ChatMessage]) {
        guard let json = encode(messages) else { return }
        write(json, Key.oldMessages)
    }

    func saveClosedAt(_ date: Date?) {
        write(date?.epochMilliseconds, Key.closedAt)
    }

    func savePreviousClosedAt(_ date: Date?) {
        write(date?.epochMilliseconds, Key.previousClosedAt)
    }

    func isAttachmentDisclaimerAccepted() -> Bool {
        do {
            return try preferences.string(forKey: Key.attachmentDisclaimerAccepted) == "true"
        } catch {
            logger.error("Read \(Key.attachmentDisclaimerAccepted) failed: \(error)")
            return false
        }
    }

    func acceptAttachmentDisclaimer() {
        write("true", Key.attachmentDisclaimerAccepted)
    }

    private func clearAll() {
        [Key.messages, Key.oldMessages, Key.messagesTimestamp, Key.closedAt, Key.previousClosedAt]
            .forEach { write(nil, $0) }
    }

    private func date(forKey key: String) throws -> Date? {
        try preferences.string(forKey: key).flatMap(Double.init).flatMap(Date.init(epochValue:))
    }

    private func messages(forKey key: String) throws -> [ChatMessage] {
        guard let data = try preferences.string(forKey: key)?.data(using: .utf8) else { return [] }
        let saved: SavedMessages
        do {
            saved = try JSONDecoder().decode(SavedMessages.self, from: data)
        } catch {
            logger.error("Saved \(key) cannot be parsed and is replaced by the next save: \(error)")
            return []
        }
        if !saved.failures.isEmpty {
            logger.error(
                "Skipped \(saved.failures.count) messages of \(key) that failed to decode, first: \(String(describing: saved.failures.first))"
            )
        }
        return saved.messages
    }

    private func write(_ value: String?, _ key: String) {
        do {
            if let value {
                try preferences.set(value, forKey: key)
            } else {
                try preferences.removeValue(forKey: key)
            }
        } catch {
            logger.error("Write \(key) failed: \(error)")
        }
    }

    private func encode(_ messages: [ChatMessage]) -> String? {
        do {
            return try String(bytes: JSONEncoder().encode(messages), encoding: .utf8)
        } catch {
            logger.error("Encode chat messages failed: \(error)")
            return nil
        }
    }
}
