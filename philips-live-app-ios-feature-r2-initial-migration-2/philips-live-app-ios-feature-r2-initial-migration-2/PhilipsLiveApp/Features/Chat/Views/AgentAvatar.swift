import Filament
import OSLog
import SwiftUI

/// The sender's picture beside an agent message: the image the chat gave, else the Philips agent picture. The dot shows
/// while the chat is connected. Without `isShown` it only holds the space, so the bubbles of a run line up.
struct AgentAvatar: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    /// The design team's Philips agent picture, exported from Figma.
    private static let imageName = "AgentAvatar"
    private static let logger = Logger(category: "AgentAvatar")

    let sender: ChatSender?
    let isShown: Bool
    let isOnline: Bool

    var body: some View {
        Group {
            if isShown {
                avatar
            } else {
                Color.clear
            }
        }
        .frame(width: themeManager.current.chatAvatarSide, height: themeManager.current.chatAvatarSide)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = senderImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                    case let .success(image):
                        DlsAvatar(image: image, status: status, size: .s32)
                    case let .failure(error):
                        fallback.onAppear { Self.logger.error("Avatar \(url, privacy: .public) failed: \(error)") }
                    default:
                        fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        DlsAvatar(image: Image(Self.imageName), status: status, size: .s32)
    }

    private var status: DlsOnlineStatus {
        isOnline ? .online : .none
    }

    private var senderImageURL: URL? {
        guard let url = sender?.imageUrl.flatMap(URL.init(string:)), url.scheme == "https" else { return nil }
        return url
    }
}
