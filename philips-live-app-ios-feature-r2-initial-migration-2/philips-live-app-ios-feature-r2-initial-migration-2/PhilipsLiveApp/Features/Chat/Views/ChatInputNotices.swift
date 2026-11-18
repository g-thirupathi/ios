import Filament
import SwiftUI

/// Upload errors sit right above the chat input, as in Figma.
struct ChatInputNotices: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let showsFileTooLarge: Bool
    let notification: AttachmentAlert?

    var body: some View {
        let dimensions = themeManager.current.dimensionTokens
        if showsFileTooLarge || notification != nil {
            VStack(spacing: dimensions.size05) {
                if showsFileTooLarge {
                    ChatNotice(
                        text: L10n.string("ChatScreen.camera_image_exceed_message"),
                        state: .error
                    )
                }
                if let notification {
                    ChatNotice(text: notification.message, state: .error)
                }
            }
            .padding(.horizontal, dimensions.size11)
            .padding(.top, dimensions.size05)
            .padding(.bottom, dimensions.size03)
        }
    }
}
