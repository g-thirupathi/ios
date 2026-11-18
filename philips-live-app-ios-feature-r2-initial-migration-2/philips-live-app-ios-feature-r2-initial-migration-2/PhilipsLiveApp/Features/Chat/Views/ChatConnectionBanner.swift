import Filament
import SwiftUI

/// Notice about the connection floating under the top bar, over the messages.
struct ChatConnectionBanner: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let banner: ChatBanner?

    var body: some View {
        let dimensions = themeManager.current.dimensionTokens
        if let banner {
            ChatNotice(
                text: L10n.string(messageKey(for: banner)),
                state: .error,
                shape: .Toast
            )
            .padding(.horizontal, dimensions.size11)
            .padding(.top, dimensions.size05)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func messageKey(for banner: ChatBanner) -> String {
        switch banner {
            case .offline: "ChatScreen.networkerror"
            case .unavailable: "ChatScreen.missing_chat_config_message"
        }
    }
}
