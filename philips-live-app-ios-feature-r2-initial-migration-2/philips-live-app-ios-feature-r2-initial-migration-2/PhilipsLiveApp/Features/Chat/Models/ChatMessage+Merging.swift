import Foundation

extension ChatMessage {
    /// How far apart the times of the two copies of one message can be.
    private static let sameDeliveryWindow: TimeInterval = 60

    func isSame(as other: ChatMessage) -> Bool {
        guard kind == other.kind, isUnconfirmedLocalCopy == other.isUnconfirmedLocalCopy else { return false }
        if let id, let otherId = other.id {
            return id == otherId
        }
        if id != nil || other.id != nil {
            return isSamePersistedMessage(as: other)
        }
        return direction == other.direction
            && timestamp != nil
            && timestamp == other.timestamp
            && text == other.text
            && state == other.state
            && hasSameAttachments(as: other)
    }

    /// Order does not matter: the SDK keeps attachments in a dictionary, so its echo lists them in any order.
    func hasSameAttachments(as other: ChatMessage) -> Bool {
        guard attachments.count == other.attachments.count else { return false }
        var remaining = other.attachments
        for attachment in attachments {
            guard let index = remaining.firstIndex(where: attachment.isSame(as:)) else { return false }
            remaining.remove(at: index)
        }
        return true
    }

    /// The SDK echo replaces our local bubble but must stay findable by the id we gave the bubble, and keeps count of
    /// the attempts to send it. Its attachments keep the order the user picked them in.
    func keepingLocalId(of local: ChatMessage) -> ChatMessage {
        var merged = self
        merged.localId = localId ?? local.localId
        merged.sendAttempt = local.sendAttempt
        let position = { (attachment: ChatAttachment) in
            local.attachments.firstIndex { $0.isSame(as: attachment) } ?? local.attachments.count
        }
        merged.attachments = attachments.enumerated()
            .sorted { first, second in
                let (firstPosition, secondPosition) = (position(first.element), position(second.element))
                return firstPosition == secondPosition ? first.offset < second.offset : firstPosition < secondPosition
            }
            .map(\.element)
        return merged
    }

    /// A locally created failed or still-sending bubble that the SDK echo of the same text may replace.
    var isReplaceableLocalCopy: Bool {
        kind == .message && isFromUser && (state == .failed || state == .sending)
    }

    /// A bubble the user just sent that the SDK has not echoed yet. It is never a duplicate of an earlier message with
    /// the same text; only its own echo replaces it, see `merging(_:)`.
    private var isUnconfirmedLocalCopy: Bool {
        id == nil && isReplaceableLocalCopy
    }

    /// Whether `other`, the chat's copy of a message, is this one that no confirmation arrived for. The chat's copy has
    /// its own id unless the message got no further than the SDK, so the content and the time decide.
    func isSameDelivery(as other: ChatMessage) -> Bool {
        if let id, id == other.id {
            return true
        }
        return isSamePersistedMessage(as: other)
    }

    private func isSamePersistedMessage(as other: ChatMessage) -> Bool {
        guard kind == .message, other.kind == .message, let timestamp, let otherTimestamp = other.timestamp else {
            return false
        }
        return direction == other.direction
            && text == other.text
            && hasSameAttachments(as: other)
            && abs(timestamp.timeIntervalSince(otherTimestamp)) < Self.sameDeliveryWindow
    }
}

extension [ChatMessage] {
    func containsSame(as message: ChatMessage) -> Bool {
        contains { $0.isSame(as: message) }
    }

    func removingDuplicates() -> [ChatMessage] {
        reduce(into: []) { unique, message in
            if let index = unique.firstIndex(where: { $0.isSame(as: message) }) {
                unique[index] = message
            } else {
                unique.append(message)
            }
        }
    }

    /// A message the SDK inserted for a send of ours carries the local id of the bubble, which it replaces. Without
    /// one it is matched by its content, see `localCopyIndex(for:)`.
    func merging(_ incoming: ChatMessage) -> [ChatMessage] {
        var messages = removingDuplicates()
        if let localId = incoming.localId, let index = messages.firstIndex(where: { $0.localId == localId }) {
            messages[index] = incoming.keepingLocalId(of: messages[index])
            return messages
        }
        if let index = messages.firstIndex(where: { $0.isSame(as: incoming) }) {
            messages[index] = incoming.keepingLocalId(of: messages[index])
            return messages
        }
        if incoming.kind == .message, incoming.isFromUser, let index = messages.localCopyIndex(for: incoming) {
            messages[index] = incoming.keepingLocalId(of: messages[index])
            return messages
        }
        return messages + [incoming]
    }

    /// The in-flight bubble wins over an older failed one with the same text, so a retyped message is not left
    /// `sending` until it times out into a false failure. Among failed copies that reached the chat, the oldest is
    /// confirmed first, as the chat confirms sends in order. A copy with an id is a different message the chat already
    /// has, and an unsent one can never be confirmed, so neither is replaced.
    private func localCopyIndex(for incoming: ChatMessage) -> Int? {
        let candidates = indices.filter {
            self[$0].id == nil && !self[$0].isUnsent && self[$0].isReplaceableLocalCopy
                && self[$0].text == incoming.text && self[$0].hasSameAttachments(as: incoming)
        }
        return candidates.first { self[$0].state == .sending } ?? candidates.first
    }

    func updatingState(id: String, state: DeliveryState, timestamp: Date?) -> [ChatMessage] {
        map { message in
            guard message.kind == .message, message.id == id else { return message }
            var updated = message
            updated.state = state
            updated.timestamp = timestamp ?? message.timestamp
            return updated
        }
    }

    func updatingDownloadUrl(attachmentId: String, downloadUrl: String) -> [ChatMessage] {
        map { message in
            var updated = message
            updated.attachments = message.attachments.map { attachment in
                guard attachment.id == attachmentId else { return attachment }
                var refreshed = attachment
                refreshed.downloadUrl = downloadUrl
                return refreshed
            }
            return updated
        }
    }
}
