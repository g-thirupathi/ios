import Filament
import SwiftUI

struct ChatMessageRow: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @Environment(\.locale) private var locale
    @ScaledMetric private var indicatorSide: CGFloat = 16
    @ScaledMetric private var spinnerDisplaySide: CGFloat = 12

    let message: ChatMessage
    let showsAvatar: Bool
    let isAgentOnline: Bool
    let onOpenAttachment: (ChatAttachment) -> Void
    var onResend: (() -> Void)?

    var body: some View {
        if !message.text.isEmpty || !message.attachments.isEmpty {
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: dimensions.size02) {
                HStack(alignment: message.isFromUser ? .center : .bottom, spacing: dimensions.size05) {
                    if message.isFromUser {
                        Spacer(minLength: dimensions.size21)
                        if isFailed, let onResend {
                            retryButton(onResend)
                        }
                    } else {
                        AgentAvatar(sender: message.sender, isShown: showsAvatar, isOnline: isAgentOnline)
                    }
                    bubble
                    if !message.isFromUser {
                        Spacer(minLength: dimensions.size21)
                    }
                }
                if isFailed {
                    failure
                } else if !formattedTimestamp.isEmpty {
                    status
                        .padding(.leading, message.isFromUser ? 0 : themeManager.current.chatAvatarInset)
                }
            }
        }
    }

    private var dimensions: DlsDimensionTokens {
        themeManager.current.dimensionTokens
    }

    private var isFailed: Bool {
        message.isFromUser && message.state == .failed
    }

    /// Same line, font and height as the timestamp row of a delivered message.
    private var failure: some View {
        DlsText(
            L10n.string("ChatScreen.error"),
            token: themeManager.current.chatBubble.typography.timestamp,
            foregroundStyle: themeManager.current.colorTokens.foreground.color.signal.error
        )
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, dimensions.size02)
    }

    private func retryButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            DlsIcon(DlsAsset("RotateForward"), size: .medium)
                .foregroundStyle(themeManager.current.colorTokens.foreground.color.primary)
                .contentShape(Rectangle().inset(by: -dimensions.size05))
        }
    }

    private var bubble: some View {
        DlsChatBubble(tailPosition: message.isFromUser ? .trailing : .leading, isLatest: true) {
            VStack(alignment: .leading, spacing: dimensions.size03) {
                if !message.text.isEmpty {
                    DlsText(Self.linkified(message.text), token: themeManager.current.fontTokens.bodyM_Book)
                }
                ForEach(Array(message.attachments.enumerated()), id: \.offset) { _, attachment in
                    MessageAttachmentView(attachment: attachment, onOpen: onOpenAttachment)
                }
            }
        }
    }

    /// Drawn outside the bubble: Filament caps its own timestamp row to the bubble width, wrapping it on short texts.
    /// Genesys has no read receipts, so sending shows Filament's spinner and sent its delivered (double) tick, in the
    /// same slot.
    private var status: some View {
        HStack(spacing: dimensions.size03) {
            DlsText(
                formattedTimestamp,
                token: themeManager.current.chatBubble.typography.timestamp,
                foregroundStyle: themeManager.current.chatBubble.color.timestamp
            )
            .lineLimit(1)
            if message.isFromUser {
                deliveryIndicator
            }
        }
        .fixedSize()
        .padding(.horizontal, dimensions.size02)
    }

    /// Filament's spinner is 24pt at its smallest, so it is scaled down inside the 16pt slot of the tick it is
    /// swapped with.
    private var deliveryIndicator: some View {
        let spinnerSide = themeManager.current.spinner.size.small
        return Group {
            if message.state == .sent {
                DlsIcon(.checkmarkDouble, size: .small)
                    .foregroundStyle(themeManager.current.chatBubble.color.deliveredIcon)
            } else {
                DlsSpinner(size: .small)
                    .frame(width: spinnerSide, height: spinnerSide)
                    .scaleEffect(spinnerDisplaySide / spinnerSide)
            }
        }
        .frame(width: indicatorSide, height: indicatorSide)
    }

    private var formattedTimestamp: String {
        guard message.kind == .message, let timestamp = message.timestamp else { return "" }
        return timestamp.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    private static let linkPattern = try? NSRegularExpression(
        pattern: #"(?:https?://|www\.)[^\s]+"#,
        options: .caseInsensitive
    )

    /// Links `http(s)://` and `www.` URLs, opening `www.` ones over https.
    static func linkified(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard let regex = linkPattern else { return attributed }
        let nsText = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            var link = nsText.substring(with: match.range)
            while let last = link.last, "),.;!?".contains(last) {
                link.removeLast()
            }
            let url = URL(string: link.lowercased().hasPrefix("www.") ? "https://\(link)" : link)
            guard let url,
                  let range = Range(
                      NSRange(location: match.range.location, length: (link as NSString).length),
                      in: text
                  ),
                  let attributedRange = Range(range, in: attributed)
            else { continue }
            attributed[attributedRange].link = url
            attributed[attributedRange].underlineStyle = .single
        }
        return attributed
    }
}
