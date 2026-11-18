import Filament

extension ChatViewModel.AttachmentAction {
    var titleKey: String {
        switch self {
            case .gallery: "ChatScreen.add_a_photo"
            case .camera: "ChatScreen.take_a_photo"
            case .document: "ChatScreen.upload_files"
        }
    }

    var icon: DlsAsset {
        switch self {
            case .gallery: .image
            case .camera: .capture
            case .document: .document
        }
    }
}
