import Filament
import SwiftUI

struct ChatScreen: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: ChatViewModel
    @State private var webPage: WebPage?
    /// Written on every scroll frame without re-rendering; only `isNearBottom` below does, and only when it flips.
    @State private var scroll = ChatScroller()
    @State private var isNearBottom = true
    @State private var isOptionsMenuPresented = false

    private static let rowInsertDuration = 0.2
    private static let probeSide: CGFloat = 1
    private static let bannerAnimationDuration = 0.25
    private static let scrollButtonAnimationDuration = 0.2

    init(viewModel: @autoclosure @escaping () -> ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatHeader(
                showsMenu: viewModel.showsOptionsMenu,
                onBack: { dismiss() },
                onMore: { isOptionsMenuPresented.toggle() }
            )
            .transformAnchorPreference(key: ChatMenuAnchorsKey.self, value: .bounds) { $0.header = $1 }
            content
        }
        .chatMenus(
            viewModel: viewModel,
            isOptionsMenuPresented: $isOptionsMenuPresented,
            inputTopInset: chatInputTopInset
        )
        .background { themeManager.current.colorTokens.container.background.primary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .swipeBackEnabled()
        .task { await viewModel.observe() }
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .onChange(of: scenePhase) { phase in
            switch phase {
                case .background: viewModel.onEnteredBackground()
                case .active: viewModel.onBecameActive()
                default: break
            }
        }
        .chatAttachmentPresentation(viewModel: viewModel)
        .environment(\.openURL, OpenURLAction { url in
            guard let page = WebPage(url: url) else { return .systemAction }
            webPage = page
            return .handled
        })
        .dlsAlertDialog(
            isPresented: $viewModel.isEndChatConfirmationPresented,
            title: L10n.key("ChatScreen.end_chat_confirmation_title")
        ) {
            dialogMessage("ChatScreen.end_chat_confirmation_message")
            DlsButton(L10n.string("ChatScreen.confirm"), fullWidth: true, action: viewModel.confirmEndChat)
            DlsButton(L10n.string("ChatScreen.cancel"), variant: .Quiet, fullWidth: true) {
                viewModel.isEndChatConfirmationPresented = false
            }
        }
        .dlsAlertDialog(
            isPresented: $viewModel.isEndChatFailurePresented,
            title: L10n.key("ChatScreen.error")
        ) {
            dialogMessage("ChatScreen.end_chat_failed_message")
            DlsButton(L10n.string("ChatScreen.ok"), fullWidth: true) {
                viewModel.isEndChatFailurePresented = false
            }
        }
        .dlsAlertDialog(
            isPresented: $viewModel.isConnectionFailurePresented,
            title: L10n.key("ChatScreen.error")
        ) {
            dialogMessage("ChatScreen.connection_error_message")
            DlsButton(L10n.string("ChatScreen.retry"), fullWidth: true, action: viewModel.retryConnection)
            DlsButton(L10n.string("ChatScreen.cancel"), variant: .Quiet, fullWidth: true) {
                viewModel.isConnectionFailurePresented = false
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
            case let .connecting(isReconnecting):
                connecting(isReconnecting)
            case .conversation:
                conversation
        }
    }

    private var dimensions: DlsDimensionTokens {
        themeManager.current.dimensionTokens
    }

    /// Space between the top of the chat input block and its text field: Filament's own padding plus ours.
    private var chatInputTopInset: CGFloat {
        themeManager.current.chatInput.size.paddingVertical + dimensions.size05
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            // The bottom edge of this section is the chat input's top edge, where the attachment menu opens.
            aboveInput
                .transformAnchorPreference(key: ChatMenuAnchorsKey.self, value: .bounds) { $0.aboveInput = $1 }
            DlsChatInput(
                text: $viewModel.draft,
                prompt: L10n.key(viewModel.placeholderKey),
                enabled: !viewModel.state.tray.isSending,
                hasAttachment: !viewModel.state.tray.items.isEmpty,
                onUpload: viewModel.toggleAttachmentMenu,
                onSend: viewModel.send
            )
            // `enabled` leaves the text field editable; it must not change while the draft is being sent.
            .disabled(viewModel.state.tray.isSending)
            .fixedSize(horizontal: false, vertical: true)
            // Filament's own 8pt padding plus this makes the design's 20pt sides and 16pt top and bottom.
            .padding(.horizontal, dimensions.size07)
            .padding(.vertical, dimensions.size05)
        }
        .overlay(alignment: .top) { ChatConnectionBanner(banner: viewModel.state.banner) }
        .animation(.easeInOut(duration: Self.bannerAnimationDuration), value: viewModel.state.banner)
    }

    private var aboveInput: some View {
        VStack(spacing: 0) {
            messageList
                .safariSheet(page: $webPage)
                .onTapGesture(perform: dismissKeyboard)
            endedBanner
            ChatInputNotices(
                showsFileTooLarge: viewModel.showsFileTooLargeError,
                notification: viewModel.attachmentNotification
            )
            if !viewModel.state.tray.items.isEmpty {
                PendingAttachmentsBar(
                    attachments: viewModel.state.tray.items,
                    onRemove: viewModel.removeAttachment
                )
            }
            if let tray = viewModel.quickReplyTray {
                quickReplies(tray)
            }
        }
    }

    /// Below the list rather than a safe-area inset of it: the flipped list would inset its content at the top.
    @ViewBuilder
    private var endedBanner: some View {
        if viewModel.state.conversation.showsChatEndedCard {
            ChatNotice(text: L10n.string("ChatScreen.chat_ended_message_description"))
                .padding(.horizontal, dimensions.size11)
                .padding(.top, dimensions.size05)
                .frame(maxWidth: .infinity)
                .background(themeManager.current.colorTokens.container.background.primary)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func open(_ attachment: ChatAttachment) {
        Task {
            webPage = await viewModel.downloadURL(for: attachment).flatMap(WebPage.init)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    messageRows
                    Color.clear
                        .frame(height: 0)
                        .chatScrollEnd()
                }
            }
            .chatScrollFlipped()
            .background {
                // Full width: iOS offers the tap only to scroll views under where the status bar was tapped.
                StatusBarTapView { scroll.scrollToOldest(proxy) }
                    .frame(height: Self.probeSide)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .coordinateSpace(name: ChatScroll.space)
            .chatScrollViewport()
            .onPreferenceChange(ChatScrollMetricsKey.self, perform: metricsChanged)
            .onAppear {
                scroll.tailItemCount = tail.itemCount
                scroll.scrollToBottomOnAppear(proxy)
            }
            .onDisappear(perform: scroll.cancel)
            .overlay(alignment: .bottomTrailing) {
                // The fade is scoped to the button; animating the scroll view itself would fight the scrolling.
                ZStack {
                    if !isNearBottom {
                        ScrollToLatestButton { scroll.scrollToBottom(proxy, animated: true) }
                            .padding(.trailing, dimensions.size07)
                            .padding(.bottom, dimensions.size03)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: Self.scrollButtonAnimationDuration), value: isNearBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            // The offset is still the one before the new rows are laid out. The user's own new message is always
            // followed, even when they had scrolled up; anything else only within `ChatScroll.nearDistance` of the
            // bottom. While a scroll to the bottom is settling, the opening one included, late-arriving history is
            // followed too.
            .onChange(of: tail) { newTail in
                let sentOwnMessage = newTail.itemCount > scroll.tailItemCount && newTail.lastMessage?.isFromUser == true
                scroll.tailItemCount = newTail.itemCount
                if sentOwnMessage || scroll.isSettling || (scroll.isWithinNearDistance && !scroll.isUserScrolling) {
                    scroll.scrollToBottom(proxy, animated: !scroll.isSettling)
                }
            }
        }
    }

    /// The list is flipped, so its content runs newest first and each row is turned back.
    private var messageRows: some View {
        LazyVStack(alignment: .leading, spacing: dimensions.size07) {
            let rows = viewModel.rows
            Color.clear
                .frame(height: Self.probeSide)
                .id(ChatScroll.bottomAnchorId)
                .chatScrollAnchor()
            if viewModel.state.isAgentTyping, !viewModel.state.conversation.showsChatEndedCard {
                TypingIndicatorRow()
                    .chatScrollFlipped()
                    // Leaves on the spot: the message replacing it slides in where it was.
                    .transition(.asymmetric(insertion: .move(edge: .top), removal: .identity))
            }
            ForEach(rows.reversed(), id: \.id) { row in
                Group {
                    switch row.item {
                        case let .message(message) where message.kind == .quickReply:
                            QuickReplyMessageRow(
                                message: message,
                                showsAvatar: row.showsAvatar,
                                isAgentOnline: viewModel.isAgentOnline
                            )
                        case let .message(message):
                            ChatMessageRow(
                                message: message,
                                showsAvatar: row.showsAvatar,
                                isAgentOnline: viewModel.isAgentOnline,
                                onOpenAttachment: open,
                                onResend: viewModel.canResend(message) ? { viewModel.resend(message) } : nil
                            )
                        case let .closedDivider(closedAt):
                            ChatClosedDivider(closedAt: closedAt)
                    }
                }
                .chatScrollFlipped()
                // The content is flipped: its top edge is the input's.
                .transition(.move(edge: .top))
            }
            DisclaimerSection(bodyKey: "DisclaimerScreen.chat_body")
                .padding(.horizontal, dimensions.size19 - dimensions.size11)
                .padding(.top, dimensions.size03)
                // The list's own padding at its oldest end, inside the row so the anchor reaches the content's end.
                .padding(.top, dimensions.size05)
                .chatScrollOldestAnchor()
                .chatScrollFlipped()
                .id(ChatScroll.oldestAnchorId)
        }
        // Near the bottom, new rows slide in from the input with the ones above; further up, nothing moves.
        .animation(scroll.isWithinNearDistance ? .easeOut(duration: Self.rowInsertDuration) : nil, value: tail)
        .overlay(alignment: .topLeading) {
            ScrollViewLocator { scroll.locator = $0 }
                .frame(width: Self.probeSide, height: Self.probeSide)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, dimensions.size11)
    }

    /// Writes `isNearBottom` only when it flips, so scrolling through the middle of the list never re-renders.
    private func metricsChanged(_ metrics: ChatScrollMetrics) {
        scroll.update(metrics)
        guard metrics.isMeasured else { return }
        let nearBottom = scroll.isNearBottom(wasNear: isNearBottom)
        if nearBottom != isNearBottom {
            isNearBottom = nearBottom
        }
    }

    /// Everything at the end of the conversation whose change (a new row, or the last row growing, e.g. a failed
    /// message gaining its Resend button) should keep a user who is at the bottom pinned there.
    private var tail: ChatTail {
        ChatTail(
            itemCount: viewModel.rows.count,
            lastMessage: viewModel.state.conversation.messages.last,
            isAgentTyping: viewModel.state.isAgentTyping,
            showsEndedCard: viewModel.state.conversation.showsChatEndedCard,
            quickReplyKey: viewModel.quickReplyTray?.key
        )
    }

    private func quickReplies(_ tray: OpenQuickReply) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: dimensions.size05) {
                ForEach(tray.options, id: \.self) { option in
                    DlsButton(option.text, variant: .Secondary) {
                        viewModel.select(option, in: tray)
                    }
                }
            }
            .padding(.horizontal, dimensions.size11)
            .padding(.vertical, dimensions.size03)
        }
    }

    private func connecting(_ isReconnecting: Bool) -> some View {
        VStack(spacing: dimensions.size09) {
            Spacer()
            DlsSpinner(size: .medium)
            dialogMessage(isReconnecting ? "ChatScreen.reconnecting_message" : "ChatScreen.connecting_message")
            Spacer()
        }
        .padding(.horizontal, dimensions.size09)
    }

    private func dialogMessage(_ key: String) -> some View {
        DlsText(L10n.string(key), token: themeManager.current.fontTokens.bodyM_Book)
            .multilineTextAlignment(.center)
            .foregroundStyle(themeManager.current.colorTokens.foreground.color.primary)
    }
}

private extension ChatScreen {
    /// Receives the status bar's scroll-to-top tap, which the flipped list itself can't take: on it, the top is the
    /// newest message. The only scroll view on screen that scrolls to the top, it hands the tap on instead of
    /// scrolling.
    struct StatusBarTapView: UIViewRepresentable {
        let onTap: () -> Void

        func makeCoordinator() -> StatusBarTapDelegate {
            StatusBarTapDelegate(onTap: onTap)
        }

        func makeUIView(context: Context) -> UIScrollView {
            let view = UIScrollView()
            view.scrollsToTop = true
            view.delegate = context.coordinator
            // Something to scroll back up from: iOS doesn't offer the tap to a scroll view already at its top.
            view.contentSize = CGSize(width: 1, height: 3)
            view.contentOffset = CGPoint(x: 0, y: 1)
            return view
        }

        func updateUIView(_: UIScrollView, context: Context) {
            context.coordinator.onTap = onTap
        }
    }

    final class StatusBarTapDelegate: NSObject, UIScrollViewDelegate {
        var onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        func scrollViewShouldScrollToTop(_: UIScrollView) -> Bool {
            onTap()
            return false
        }
    }
}
