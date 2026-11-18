import Foundation

/// Persisted as JSON in the Keychain with R1's field names and values, so R1 history loads after the update.
struct ChatMessage: Codable, Equatable {
    enum Kind: String, Codable {
        case message
        case quickReply = "quickreply"
    }

    /// Genesys naming: `inbound` is sent by the user, `outbound` by the agent.
    enum Direction: String, Codable {
        case inbound = "Inbound"
        case outbound = "Outbound"
    }

    var id: String?
    /// Ours, set on every message the user sends: the SDK id only exists once the SDK has inserted the message.
    var localId: String?
    var kind: Kind
    var direction: Direction
    var text: String
    var state: DeliveryState
    var timestamp: Date?
    var options: [QuickReplyOption]
    var attachments: [ChatAttachment]
    /// Set on agent messages, whose sender is shown beside them.
    var sender: ChatSender?
    /// A failed own message that never reached the chat, so no echo can confirm it. Known only until the app quits,
    /// so it is not saved.
    var isUnsent = false
    /// Counts the times the user sent this message again, so a timer or send left over from an earlier attempt can
    /// tell it no longer applies. Known only until the app quits, so it is not saved.
    var sendAttempt = 0

    var isFromUser: Bool {
        direction == .inbound
    }

    init(
        id: String? = nil,
        localId: String? = nil,
        kind: Kind = .message,
        direction: Direction,
        text: String,
        state: DeliveryState,
        timestamp: Date?,
        options: [QuickReplyOption] = [],
        attachments: [ChatAttachment] = [],
        sender: ChatSender? = nil
    ) {
        self.id = id
        self.localId = localId
        self.kind = kind
        self.direction = direction
        self.text = text
        self.state = state
        self.timestamp = timestamp
        self.options = options
        self.attachments = attachments
        self.sender = sender
    }

    private enum CodingKeys: String, CodingKey {
        case id, localId, type, direction, text, state, timestamp, options, attachments, sender
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        localId = try container.decodeIfPresent(String.self, forKey: .localId)
        kind = try container.decodeIfPresent(Kind.self, forKey: .type) ?? .message
        direction = try container.decodeIfPresent(Direction.self, forKey: .direction) ?? .outbound
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        state = try DeliveryState(storedValue: container.decodeIfPresent(String.self, forKey: .state) ?? "")
        timestamp = Self.decodeTimestamp(from: container)
        options = try container.decodeIfPresent([QuickReplyOption].self, forKey: .options) ?? []
        attachments = try container.decodeIfPresent([ChatAttachment].self, forKey: .attachments) ?? []
        sender = try? container.decodeIfPresent(ChatSender.self, forKey: .sender)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(localId, forKey: .localId)
        try container.encode(kind, forKey: .type)
        try container.encode(direction, forKey: .direction)
        try container.encode(text, forKey: .text)
        try container.encode(state.rawValue, forKey: .state)
        try container.encodeIfPresent(timestamp?.epochMilliseconds, forKey: .timestamp)
        try container.encode(options, forKey: .options)
        try container.encode(attachments, forKey: .attachments)
        try container.encodeIfPresent(sender, forKey: .sender)
    }

    /// R1 wrote epoch milliseconds as either a number or a numeric string.
    private static func decodeTimestamp(from container: KeyedDecodingContainer<CodingKeys>) -> Date? {
        let raw: Double? = if let number = try? container.decode(Double.self, forKey: .timestamp) {
            number
        } else if let text = try? container.decode(String.self, forKey: .timestamp) {
            Double(text)
        } else {
            nil
        }
        return raw.flatMap(Date.init(epochValue:))
    }
}
