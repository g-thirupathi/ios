import Filament
import SwiftUI

/// A sent or received attachment inside a chat bubble; tapping opens it.
struct MessageAttachmentView: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let attachment: ChatAttachment
    let onOpen: (ChatAttachment) -> Void

    var body: some View {
        Button { onOpen(attachment) } label: {
            VStack(alignment: .leading, spacing: themeManager.current.dimensionTokens.size03) {
                if attachment.isImage, let url = previewURL {
                    // The image is an overlay so its fill size cannot widen the bubble.
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: themeManager.current.dimensionTokens.size33)
                        .overlay { AttachmentThumbnail(url: url).id(url) }
                        .clipShape(RoundedRectangle(cornerRadius: themeManager.current.dimensionTokens.size05))
                }
                HStack(spacing: themeManager.current.dimensionTokens.size03) {
                    DlsIcon(attachment.isImage ? .fileImage : .document, size: .medium)
                    AttachmentLabel(fileName: attachment.fileName, fileSize: attachment.fileSize)
                }
            }
            .padding(themeManager.current.dimensionTokens.size05)
            .background(themeManager.current.colorTokens.container.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: themeManager.current.dimensionTokens.size05))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(attachment.id == nil && attachment.downloadUrl == nil)
    }

    /// Previews are local cache files and disappear when the system purges Caches.
    private var previewURL: URL? {
        guard let url = attachment.previewUri.flatMap(URL.init(string:)),
              !url.isFileURL || FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }
}
