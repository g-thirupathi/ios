import Filament
import SwiftUI

struct PendingAttachmentChip: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let attachment: PendingAttachment
    let onRemove: () -> Void

    private let width: CGFloat = 260
    @ScaledMetric private var thumbnailSize: CGFloat = 42
    @ScaledMetric private var minHeight: CGFloat = 62

    var body: some View {
        HStack(spacing: themeManager.current.dimensionTokens.size05) {
            if attachment.state.isInProgress {
                DlsSpinner(size: .small)
                    .frame(width: thumbnailSize, height: thumbnailSize)
            } else if attachment.isImage {
                AttachmentThumbnail(url: attachment.fileURL)
                    .id(attachment.fileURL)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: themeManager.current.dimensionTokens.size05))
            } else {
                DlsIcon(.document, size: .large)
                    .frame(width: thumbnailSize, height: thumbnailSize)
            }
            AttachmentLabel(fileName: attachment.fileName, fileSize: attachment.fileSize)
            DlsButton("", variant: .Quiet, icon: DlsAsset.cross, action: onRemove)
                .accessibilityLabel(Text(attachment.fileName))
        }
        .padding(.horizontal, themeManager.current.dimensionTokens.size05)
        .frame(width: width)
        .frame(minHeight: minHeight)
        .background(themeManager.current.colorTokens.container.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.current.dimensionTokens.size07))
    }
}
