import Foundation

extension AttachmentAlert {
    /// Shown as a notification above the chat input; the other alerts stay dialogs.
    var isNotification: Bool {
        switch self {
            case .limitReached, .onlyFilesAdded, .unsupported, .invalid, .attachFailed, .uploadFailed: true
            default: false
        }
    }

    var titleKey: String {
        switch self {
            case .limitReached, .onlyFilesAdded: "ChatScreen.limit_reached_title"
            case .duplicates: "ChatScreen.duplicate_media_alert_title"
            case .cameraUnavailable: "ChatScreen.camera_error_message"
            case .cameraPermissionDenied: "ChatScreen.permission_denied_title"
            case .uploadFailed: "ChatScreen.upload_failed_title"
            default: "ChatScreen.error"
        }
    }

    var message: String {
        switch self {
            case .limitReached: L10n.string("ChatScreen.limit_reached_message")
            case let .onlyFilesAdded(count): String(format: L10n.string("ChatScreen.only_files_added_message"), count)
            case .duplicates: L10n.string("ChatScreen.duplicate_media_alert_message")
            case .unsupported: L10n.string("ChatScreen.unsupported_attachment_message")
            case .invalid: L10n.string("ChatScreen.invalid_attachment_message")
            case .readFailed: L10n.string("ChatScreen.read_attachment_failed_message")
            case .pickPhotoFailed: L10n.string("ChatScreen.pick_gallery_failed_message")
            case .pickFileFailed: L10n.string("ChatScreen.pick_file_failed_message")
            case .takePhotoFailed: L10n.string("ChatScreen.fail_to_take_photo_message")
            case .cameraUnavailable: L10n.string("ChatScreen.camera_unavailable_message")
            case .cameraPermissionDenied: L10n.string("ChatScreen.permission_denied_message")
            case .networkError: L10n.string("ChatScreen.networkerror")
            case .chatUnavailable: L10n.string("ChatScreen.missing_chat_config_message")
            case let .attachFailed(fileName): sentence(L10n.string("ChatScreen.failed_to_attach_message"), fileName)
            case let .uploadFailed(fileName): sentence(fileName, L10n.string("ChatScreen.upload_failed_message"))
        }
    }

    /// The translations carry their own spaces at the edges in some languages and none in others.
    private func sentence(_ parts: String...) -> String {
        parts.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
    }
}
