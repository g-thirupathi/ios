import Foundation

extension AttachmentTray {
    mutating func add(_ attachment: PendingAttachment) {
        items.append(attachment)
    }

    mutating func remove(id: PendingAttachment.ID) {
        items.removeAll { $0.id == id }
    }

    mutating func beginSend() {
        isSending = true
        for index in items.indices {
            items[index].state = .presigning
        }
    }

    /// The files that were sent leave the tray; ones picked while they uploaded stay for the next message.
    mutating func finishSend(sentIds: Set<PendingAttachment.ID>) {
        isSending = false
        items.removeAll { sentIds.contains($0.id) }
    }

    /// Nothing was sent: the tray stays as it was, so the user can try again.
    mutating func cancelSend() {
        isSending = false
        for index in items.indices {
            items[index].state = .ready
        }
    }

    mutating func failSend(alert: AttachmentAlert) {
        cancelSend()
        self.alert = alert
    }

    /// Upload states reach the tray by the item's id; updates of attachments that came from no item are ignored.
    mutating func updateItem(pendingId: PendingAttachment.ID?, state: AttachmentUploadState) {
        guard let index = items.firstIndex(where: { $0.id == pendingId }) else { return }
        items[index].state = state
    }

    mutating func showAlert(_ alert: AttachmentAlert) {
        self.alert = alert
    }

    mutating func dismissAlert() {
        alert = nil
    }
}
