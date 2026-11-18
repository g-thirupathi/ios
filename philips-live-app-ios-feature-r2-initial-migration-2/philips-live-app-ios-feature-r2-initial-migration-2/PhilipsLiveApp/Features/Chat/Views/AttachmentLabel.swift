import Filament
import SwiftUI

struct AttachmentLabel: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @Environment(\.locale) private var locale

    let fileName: String
    let fileSize: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: themeManager.current.dimensionTokens.size02) {
            DlsText(fileName, token: themeManager.current.fontTokens.bodyS_Bold)
                .lineLimit(1)
                .truncationMode(.middle)
            if let fileSize, fileSize > 0 {
                DlsText(
                    ChatAttachment.formattedSize(fileSize, locale: locale),
                    token: themeManager.current.fontTokens.bodyS_Book,
                    foregroundStyle: themeManager.current.colorTokens.foreground.color.secondary
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
