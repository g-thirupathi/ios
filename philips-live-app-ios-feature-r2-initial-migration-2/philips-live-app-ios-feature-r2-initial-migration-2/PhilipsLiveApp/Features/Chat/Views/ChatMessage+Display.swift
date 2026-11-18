import Foundation

extension ChatMessage {
    /// Whether the row of this message draws anything.
    var hasContent: Bool {
        !text.isEmpty || !attachments.isEmpty
    }
}
