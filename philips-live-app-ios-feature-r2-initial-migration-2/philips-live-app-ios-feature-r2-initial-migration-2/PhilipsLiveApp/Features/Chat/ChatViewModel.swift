import Foundation
import OSLog

final class ChatViewModel: ObservableObject {
    enum Content: Equatable {
        case connecting(isReconnecting: Bool)
        case conversation
    }

    enum AttachmentAction: CaseIterable, Hashable {
        case gallery
        case camera
        case document
    }

    @Published private(set) var state: ChatSession {
        didSet {
            let items = state.conversation.listItems
            if items != rows.map(\.item) {
                rows = ChatListRow.rows(for: items)
            }
        }
    }

    /// Built once per change of the conversation, not on every render.
    @Published private(set) var rows: [ChatListRow]
    @Published var draft = ""
    @Published var isEndChatConfirmationPresented = false
    @Published var isEndChatFailurePresented = false
    @Published var isConnectionFailurePresented = false
    @Published var isAttachmentMenuPresented = false
    @Published var pendingDisclaimerAction: AttachmentAction?
    @Published var activePicker: AttachmentAction?
    @Published private(set) var showsFileTooLargeError = false
    @Published private var localAlert: AttachmentAlert?
    @Published private var dismissedQuickReplyKey: String?
    @Published private var country: SupportCountry

    /// Lets a dismissing full-screen dialog or picker finish before the next one is presented.
    private static let presentationDelay: Duration = .milliseconds(450)

    private let chat: ChatRepository
    private let attachments: ChatAttachmentRepository
    private let countryRepository: SupportCountryRepository
    private let connectChat: ConnectChatUseCase
    private let sendText: SendTextMessageUseCase
    private let sendAttachments: SendAttachmentsUseCase
    private let resendMessage: ResendMessageUseCase
    private let addAttachmentsUseCase: AddAttachmentsUseCase
    private let removeAttachmentUseCase: RemoveAttachmentUseCase
    private let openAttachment: OpenAttachmentUseCase
    private let endChat: EndChatUseCase
    private let cameraPermission: CameraPermissionRepository
    private let logger = Logger(category: "ChatViewModel")

    init(
        chat: ChatRepository,
        attachments: ChatAttachmentRepository,
        countryRepository: SupportCountryRepository,
        connectChat: ConnectChatUseCase,
        sendText: SendTextMessageUseCase,
        sendAttachments: SendAttachmentsUseCase,
        resendMessage: ResendMessageUseCase,
        addAttachments: AddAttachmentsUseCase,
        removeAttachment: RemoveAttachmentUseCase,
        openAttachment: OpenAttachmentUseCase,
        endChat: EndChatUseCase,
        cameraPermission: CameraPermissionRepository
    ) {
        self.chat = chat
        self.attachments = attachments
        self.countryRepository = countryRepository
        self.connectChat = connectChat
        self.sendText = sendText
        self.sendAttachments = sendAttachments
        self.resendMessage = resendMessage
        addAttachmentsUseCase = addAttachments
        removeAttachmentUseCase = removeAttachment
        self.openAttachment = openAttachment
        self.endChat = endChat
        self.cameraPermission = cameraPermission
        state = chat.session
        rows = ChatListRow.rows(for: chat.session.conversation.listItems)
        country = countryRepository.selectedCountry()
    }

    /// Shown from the start; its items stay disabled until they can be used.
    var showsOptionsMenu: Bool {
        country.hasChatOptionsMenu
    }

    var canEndChat: Bool {
        state.canEndChat(in: country)
    }

    var attachmentAlert: AttachmentAlert? {
        currentAlert.flatMap { $0.isNotification ? nil : $0 }
    }

    var attachmentNotification: AttachmentAlert? {
        currentAlert.flatMap { $0.isNotification ? $0 : nil }
    }

    private var currentAlert: AttachmentAlert? {
        localAlert ?? state.tray.alert
    }

    var remainingAttachmentSlots: Int {
        max(ChatAttachment.maxCount - state.tray.items.count, 0)
    }

    /// A first-time user sees the connecting message only while the chat is being reached. Once it is not (no network,
    /// refused, failed) the conversation is shown, with the notice or dialog for the reason over it.
    var content: Content {
        let connection = state.connection
        let isReaching = connection.status == .connecting || connection.status == .reconnecting
        if isReaching, !connection.isConfigured, !connection.isReadOnly, !state.canShowChatSurface {
            return .connecting(isReconnecting: connection.status == .reconnecting)
        }
        return .conversation
    }

    var placeholderKey: String {
        state.conversation.isRestartedChat && !state.conversation.hasRestartedChatStarted
            ? "ChatScreen.message_placeholder"
            : "ChatScreen.add_your_message"
    }

    /// The avatar's dot shows while the chat is connected.
    var isAgentOnline: Bool {
        state.connection.status == .connected
    }

    /// The open quick replies, unless the user dismissed them.
    var quickReplyTray: OpenQuickReply? {
        state.conversation.openQuickReply.flatMap { $0.key == dismissedQuickReplyKey ? nil : $0 }
    }

    /// While the screen is open, a returning network brings the chat back, or confirms it never went down, and closes
    /// the network error dialog along with the banner. The dialog never shows over a banner: a failure that comes with
    /// one waits for the banner to clear. A clear confirmed after "end chat" timed out still ends the chat, so its
    /// failure alert no longer applies.
    func observe() async {
        for await session in chat.sessions() {
            let wasNetworkAvailable = state.connection.isNetworkAvailable
            let hadConnectivity = state.connection.hasConnectivity
            let couldOfferRetry = state.connection.isFailed && state.banner == nil
            state = session
            if session.connection.hasConnectivity, !hadConnectivity, attachmentAlert == .networkError {
                dismissAttachmentAlert()
            }
            if session.conversation.isChatEnded, isEndChatFailurePresented {
                isEndChatFailurePresented = false
            }
            let isRestoringNetwork = session.connection.isNetworkAvailable && !wasNetworkAvailable
            let canOfferRetry = session.connection.isFailed && session.banner == nil
            if !canOfferRetry {
                isConnectionFailurePresented = false
            } else if !couldOfferRetry, session.isScreenActive, !isRestoringNetwork {
                isConnectionFailurePresented = true
            }
            if isRestoringNetwork, session.isScreenActive {
                connectChat.execute(.networkRestored)
            }
        }
    }

    func onAppear() {
        country = countryRepository.selectedCountry()
        connectChat.execute(.screenAppeared)
    }

    func onDisappear() {
        chat.update { $0.screenDidDisappear() }
    }

    func onEnteredBackground() {
        chat.update { $0.connection.markBackgrounded(at: .now) }
    }

    func onBecameActive() {
        connectChat.execute(.appBecameActive)
    }

    func send() {
        let draftText = draft
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        dismissAttachmentNotices()
        guard !state.tray.items.isEmpty else {
            draft = ""
            if !text.isEmpty {
                sendText.execute(text)
            }
            return
        }
        guard !state.tray.isSending else { return }
        Task {
            if await sendAttachments.execute(text), draft == draftText {
                state = chat.session
                draft = ""
            }
        }
    }

    func select(_ option: QuickReplyOption, in tray: OpenQuickReply) {
        dismissAttachmentNotices()
        dismissedQuickReplyKey = tray.key
        sendText.execute(option.text)
    }

    func canResend(_ message: ChatMessage) -> Bool {
        state.conversation.canResend(message)
    }

    func resend(_ message: ChatMessage) {
        resendMessage.execute(message)
    }

    func toggleAttachmentMenu() {
        dismissAttachmentNotices()
        isAttachmentMenuPresented.toggle()
    }

    /// The attachment disclaimer shows once, after the user picks a source from the menu.
    func requestAttachment(_ action: AttachmentAction) {
        isAttachmentMenuPresented = false
        if attachments.isDisclaimerAccepted() {
            Task { await present(action) }
        } else {
            pendingDisclaimerAction = action
        }
    }

    func confirmAttachmentDisclaimer() {
        guard let action = pendingDisclaimerAction else { return }
        attachments.acceptDisclaimer()
        pendingDisclaimerAction = nil
        Task {
            try? await Task.sleep(for: Self.presentationDelay)
            await present(action)
        }
    }

    func addAttachments(_ sources: [AttachmentSource]) {
        guard !sources.isEmpty else { return }
        dismissAttachmentNotices()
        Task {
            let result = await addAttachmentsUseCase.execute(sources)
            showsFileTooLargeError = result.hasOversizedFile
            if let alert = result.alert {
                await showAlert(alert)
            }
        }
    }

    func attachmentPickerFailed(_ action: AttachmentAction, error: Error? = nil) {
        logger.error("Picker \(String(describing: action)) failed: \(error.map(String.init(describing:)) ?? "unknown")")
        let alert: AttachmentAlert = switch action {
            case .gallery: .pickPhotoFailed
            case .camera: .takePhotoFailed
            case .document: .pickFileFailed
        }
        Task { await showAlert(alert) }
    }

    func removeAttachment(_ attachment: PendingAttachment) {
        dismissAttachmentNotices()
        removeAttachmentUseCase.execute(id: attachment.id)
    }

    func downloadURL(for attachment: ChatAttachment) async -> URL? {
        dismissAttachmentNotices()
        do {
            return try await openAttachment.execute(attachment)
        } catch is CancellationError {
            return nil
        } catch {
            localAlert = .networkError
            return nil
        }
    }

    func dismissAttachmentAlert() {
        localAlert = nil
        chat.update { $0.tray.dismissAlert() }
    }

    func retryConnection() {
        isConnectionFailurePresented = false
        connectChat.execute(.retryTapped)
    }

    func requestEndChat() {
        guard canEndChat else { return }
        isEndChatConfirmationPresented = true
    }

    private func present(_ action: AttachmentAction) async {
        guard remainingAttachmentSlots > 0 else {
            localAlert = .limitReached
            return
        }
        if action == .camera {
            guard cameraPermission.isCameraAvailable else {
                localAlert = .cameraUnavailable
                return
            }
            guard await cameraPermission.requestAccess() else {
                localAlert = .cameraPermissionDenied
                return
            }
        }
        activePicker = action
    }

    private func showAlert(_ alert: AttachmentAlert) async {
        if !alert.isNotification {
            try? await Task.sleep(for: Self.presentationDelay)
        }
        localAlert = alert
    }

    private func dismissAttachmentNotices() {
        showsFileTooLargeError = false
        if attachmentNotification != nil {
            dismissAttachmentAlert()
        }
    }

    func confirmEndChat() {
        isEndChatConfirmationPresented = false
        Task {
            do {
                try await endChat.execute()
            } catch {
                isEndChatFailurePresented = true
            }
        }
    }
}
