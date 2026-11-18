import Filament
import SwiftUI

struct PendingAttachmentsBar: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let attachments: [PendingAttachment]
    let onRemove: (PendingAttachment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: dimensions.size03) {
            HStack(spacing: dimensions.size03) {
                DlsIcon(.informationCircle, size: .small)
                DlsText(
                    L10n.string("ChatScreen.attachment_limit_hint"),
                    token: themeManager.current.fontTokens.bodyS_Book,
                    foregroundStyle: themeManager.current.colorTokens.foreground.color.secondary
                )
            }
            .foregroundStyle(themeManager.current.colorTokens.foreground.color.secondary)
            .padding(.horizontal, dimensions.size11)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: dimensions.size05) {
                    ForEach(attachments) { attachment in
                        PendingAttachmentChip(attachment: attachment) {
                            onRemove(attachment)
                        }
                    }
                }
                .padding(.horizontal, dimensions.size11)
            }
        }
        .padding(.vertical, dimensions.size03)
    }

    private var dimensions: DlsDimensionTokens {
        themeManager.current.dimensionTokens
    }
}
