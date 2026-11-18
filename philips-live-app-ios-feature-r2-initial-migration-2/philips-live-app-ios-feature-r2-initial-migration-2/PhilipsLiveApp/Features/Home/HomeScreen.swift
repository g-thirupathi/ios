import Filament
import SwiftUI

struct HomeScreen: View {
    /// Grows with Dynamic Type, so the message and button keep their room.
    @ScaledMetric private var callCardHeight: CGFloat = 200
    @EnvironmentObject private var themeManager: DlsThemeManager
    @Environment(\.openURL) private var openURL
    @Environment(\.layoutDirection) private var layoutDirection
    @StateObject private var viewModel: HomeViewModel

    let onOpenChat: () -> Void

    init(viewModel: @autoclosure @escaping () -> HomeViewModel, onOpenChat: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onOpenChat = onOpenChat
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: dimensions.size11) {
                header
                chatCard
                callCard
            }
            .padding(.horizontal, dimensions.size11)
            .padding(.vertical, dimensions.size11)
        }
        .bouncesOnlyWhenScrollable()
        .background { themeManager.current.colorTokens.container.background.primary.ignoresSafeArea() }
        .task { await viewModel.observe() }
        .dlsAlertDialog(isPresented: isAlertPresented, title: L10n.key(viewModel.alert?.titleKey ?? "")) {
            DlsText(viewModel.alert?.message ?? "", token: themeManager.current.fontTokens.bodyM_Book)
                .multilineTextAlignment(.center)
                .foregroundStyle(themeManager.current.colorTokens.foreground.color.primary)
            DlsButton(L10n.string("ChatScreen.ok"), fullWidth: true) { viewModel.alert = nil }
        }
    }

    private var dimensions: DlsDimensionTokens {
        themeManager.current.dimensionTokens
    }

    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.alert != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.alert = nil
                }
            }
        )
    }

    private var header: some View {
        let theme = themeManager.current
        return VStack(alignment: .leading, spacing: dimensions.size07) {
            DlsText(
                L10n.string("HomeScreen.header_title"),
                token: theme.fontTokens.headingS_Bold,
                foregroundStyle: theme.colorTokens.foreground.color.primary
            )
            .accessibilityAddTraits(.isHeader)
            DlsText(
                L10n.string("HomeScreen.section_title"),
                token: theme.fontTokens.bodyL_Book,
                foregroundStyle: theme.colorTokens.foreground.color.secondary
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chatCard: some View {
        let theme = themeManager.current
        return DlsCard(.primaryColor) {
            DlsCardPadding {
                VStack(alignment: .leading, spacing: dimensions.size11) {
                    VStack(alignment: .leading, spacing: dimensions.size05) {
                        DlsPictogram(.personHeadset, size: .small)
                            .accessibilityHidden(true)
                        DlsText(
                            L10n.string("HomeScreen.philips_live_agent"),
                            token: theme.fontTokens.headingS_Bold,
                            foregroundStyle: theme.colorTokens.foreground.color.primary
                        )
                        DlsText(
                            L10n.string("HomeScreen.chat_message_title"),
                            token: theme.fontTokens.bodyL_Book,
                            foregroundStyle: theme.colorTokens.foreground.color.secondary
                        )
                        if viewModel.unreadCount > 0 {
                            unreadIndicator
                        }
                    }
                    DlsButton(
                        L10n.string("HomeScreen.chat_now"),
                        icon: .chat,
                        fullWidth: true,
                        action: onOpenChat
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var unreadIndicator: some View {
        HStack(spacing: dimensions.size03) {
            DlsText(
                L10n.string("HomeScreen.unread_msg"),
                token: themeManager.current.fontTokens.bodyM_Book,
                foregroundStyle: themeManager.current.colorTokens.foreground.color.primary
            )
            DlsBadge(value: viewModel.unreadCount, badgeStateVariant: .normal)
        }
        .accessibilityElement(children: .combine)
    }

    private var callCard: some View {
        let theme = themeManager.current
        let buttonSize = theme.button.size
        let buttonIconSize: CGFloat = switch buttonSize.icon {
            case .small: theme.iconTokens.small
            case .medium: theme.iconTokens.regular
            case .large: theme.iconTokens.large
        }
        return DlsCard {
            CallCardLayout(
                maxImageWidth: Self.callImageWidth,
                leadingGap: dimensions.size09,
                trailingInset: theme.card.size.paddingHorizontal,
                verticalInset: theme.card.size.paddingVertical,
                rowSpacing: dimensions.size09,
                buttonFixedWidth: buttonSize.paddingLeft + buttonSize.paddingRight + buttonSize.gap + buttonIconSize,
                buttonMinLabelScale: Self.callButtonMinLabelScale,
                isRightToLeft: layoutDirection == .rightToLeft
            ) {
                Image("CallUsCard")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .accessibilityHidden(true)
                callMessage
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                DlsButton(
                    L10n.string("HomeScreen.call_us"),
                    variant: .Danger,
                    icon: .call,
                    action: call
                )
                .lineLimit(1)
                .minimumScaleFactor(Self.callButtonMinLabelScale)
            }
            .frame(height: callCardHeight)
        }
    }

    private static let callImageWidth: CGFloat = 172
    private static let callButtonMinLabelScale: CGFloat = 0.75

    private var callMessage: some View {
        let font = themeManager.current.fontTokens.bodyM_Book
        return Text(L10n.string("HomeScreen.call_us_msg"))
            .font(font.font())
            .lineSpacing(font.lineSpacing())
            .foregroundStyle(themeManager.current.colorTokens.foreground.color.primary)
    }

    private func call() {
        guard let url = viewModel.callURL() else { return }
        openURL(url) { accepted in
            if !accepted {
                viewModel.callDidFail()
            }
        }
    }
}
