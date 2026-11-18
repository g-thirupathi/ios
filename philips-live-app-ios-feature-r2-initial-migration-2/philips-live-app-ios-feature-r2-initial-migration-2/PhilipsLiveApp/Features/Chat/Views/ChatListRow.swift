import Foundation

/// A chat list item with an identity that survives rows being inserted before it.
struct ChatListRow: Identifiable, Equatable {
    let id: String
    let item: ChatListItem
    /// The last agent message of a run from one sender, which that sender's avatar sits beside.
    let showsAvatar: Bool

    /// Messages are identified by our local id, which stays when the SDK's echo merges in, else by the SDK id.
    /// A repeated id gets a suffix, so the list never holds two rows with one identity.
    static func rows(for items: [ChatListItem]) -> [ChatListRow] {
        var counts: [String: Int] = [:]
        return items.enumerated().map { index, item in
            let base = switch item {
                case let .message(message): message.localId ?? message.id ?? "message"
                case let .closedDivider(date): "closed-\(date.timeIntervalSince1970)"
            }
            let count = counts[base, default: 0]
            counts[base] = count + 1
            return ChatListRow(
                id: count == 0 ? base : "\(base)-\(count)",
                item: item,
                showsAvatar: endsAgentRun(at: index, in: items)
            )
        }
    }

    /// Messages without content are skipped, as they draw no row.
    private static func endsAgentRun(at index: Int, in items: [ChatListItem]) -> Bool {
        guard case let .message(message) = items[index], !message.isFromUser, message.hasContent else { return false }
        for item in items[(index + 1)...] {
            guard case let .message(following) = item else { return true }
            if following.hasContent {
                return following.isFromUser || following.sender != message.sender
            }
        }
        return true
    }
}
