import Filament
import SwiftUI

struct QuickReplyMessageRow: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let message: ChatMessage
    let showsAvatar: Bool
    let isAgentOnline: Bool

    var body: some View {
        if !message.text.isEmpty {
            HStack(alignment: .bottom, spacing: themeManager.current.dimensionTokens.size05) {
                AgentAvatar(sender: message.sender, isShown: showsAvatar, isOnline: isAgentOnline)
                DlsChatBubble(tailPosition: .leading, isLatest: false) {
                    DlsText(ChatMessageRow.linkified(message.text), token: themeManager.current.fontTokens.bodyM_Book)
                }
                Spacer(minLength: themeManager.current.dimensionTokens.size21)
            }
        }
    }
}
