import Foundation

/// The composition root: the only place that creates implementations.
final class AppDependencies {
    private let countryRepository: SupportCountryRepository
    private let languageRepository: LanguageRepository
    private let chatRepository: ChatRepository
    private let chatAttachmentRepository: ChatAttachmentRepository
    /// Held for the app's lifetime: the path monitor stops as soon as the provider is freed.
    private let connectivity: ConnectivityProvider

    private lazy var getChatConfiguration: GetChatConfigurationUseCase = DefaultGetChatConfigurationUseCase(
        countryRepository: countryRepository,
        configurationRepository: DefaultChatConfigurationRepository(provider: InfoPlistAppConfigurationProvider())
    )

    private lazy var restartChat: RestartChatUseCase = DefaultRestartChatUseCase(
        chat: chatRepository,
        getConfiguration: getChatConfiguration
    )

    private lazy var waitForTransport: WaitForTransportUseCase = DefaultWaitForTransportUseCase(chat: chatRepository)

    private lazy var waitForChatConnection: WaitForChatConnectionUseCase = DefaultWaitForChatConnectionUseCase(
        chat: chatRepository,
        restart: restartChat,
        waitForTransport: waitForTransport
    )

    private lazy var watchDelivery: WatchDeliveryUseCase = DefaultWatchDeliveryUseCase(chat: chatRepository)

    private lazy var verifyMessageDelivered: VerifyMessageDeliveredUseCase =
        DefaultVerifyMessageDeliveredUseCase(chat: chatRepository)

    private lazy var deliverTextMessage: DeliverTextMessageUseCase = DefaultDeliverTextMessageUseCase(
        chat: chatRepository,
        restart: restartChat,
        waitForTransport: waitForTransport,
        watchDelivery: watchDelivery,
        verifyDelivered: verifyMessageDelivered
    )

    private lazy var prepareAttachmentTransport: PrepareAttachmentTransportUseCase =
        DefaultPrepareAttachmentTransportUseCase(chat: chatRepository, waitForConnection: waitForChatConnection)

    init() {
        let preferences = KeychainPreferencesLocalDataSource()
        // First, as the Keychain survives uninstalling and nothing may read what an earlier install left in it.
        let marker = UserDefaultsInstallMarkerLocalDataSource()
        let install = DefaultInstallRepository(marker: marker, preferences: preferences)
        DefaultClearLeftoverDataUseCase(install: install).execute()
        #if DEBUG
            Self.resetIfRequested(in: preferences)
        #endif
        languageRepository = DefaultLanguageRepository(
            preferences: preferences,
            localization: BundleLocalizationProvider()
        )
        countryRepository = DefaultSupportCountryRepository(preferences: preferences)
        // The chat history is readable only while the device is unlocked, like its attachment files.
        let chatLocal = KeychainChatLocalDataSource(
            preferences: KeychainPreferencesLocalDataSource(protection: .whileUnlocked)
        )
        chatAttachmentRepository = DefaultChatAttachmentRepository(
            files: FileChatAttachmentLocalDataSource(),
            local: chatLocal,
            images: ImageIOImageConversionProvider()
        )
        let connectivity = NWPathConnectivityProvider()
        self.connectivity = connectivity
        chatRepository = DefaultChatRepository(
            remote: GenesysChatRemoteDataSource(),
            local: chatLocal,
            attachments: chatAttachmentRepository,
            connectivity: connectivity
        )
    }

    #if DEBUG
        private static let resetArgument = "-reset"
        private static let resetOnboardingArgument = "-resetOnboarding"

        /// The Keychain survives reinstalling, so launch arguments are the way back to a first launch on a device.
        /// `-reset` wipes the app's whole Keychain: preferences, chat history and the chat session. `-resetOnboarding`
        /// clears only the onboarding, country and language, so the first-launch flow shows again.
        private static func resetIfRequested(in preferences: PreferencesLocalDataSource) {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains(resetArgument) {
                try? preferences.wipeKeychain()
            } else if arguments.contains(resetOnboardingArgument) {
                for key in [
                    DefaultSupportCountryRepository.onboardingCompletedKey,
                    DefaultSupportCountryRepository.selectedCountryKey,
                    DefaultLanguageRepository.selectedLanguageKey,
                ] {
                    try? preferences.removeValue(forKey: key)
                }
            }
        }
    #endif

    func makeRootViewModel() -> RootViewModel {
        RootViewModel(
            languageRepository: languageRepository,
            checkOnboarding: DefaultCheckOnboardingUseCase(countryRepository: countryRepository)
        )
    }

    func makeLanguageRegionViewModel() -> LanguageRegionViewModel {
        LanguageRegionViewModel(
            updateLanguageRegion: DefaultUpdateLanguageRegionUseCase(
                countryRepository: countryRepository,
                languageRepository: languageRepository
            )
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(chatRepository: chatRepository, countryRepository: countryRepository)
    }

    func makeChatViewModel() -> ChatViewModel {
        let chat = chatRepository
        let attachments = chatAttachmentRepository
        return ChatViewModel(
            chat: chat,
            attachments: attachments,
            countryRepository: countryRepository,
            connectChat: DefaultConnectChatUseCase(
                chat: chat,
                getConfiguration: getChatConfiguration,
                restart: restartChat
            ),
            sendText: DefaultSendTextMessageUseCase(chat: chat, deliver: deliverTextMessage),
            sendAttachments: DefaultSendAttachmentsUseCase(
                chat: chat,
                attachments: attachments,
                prepareTransport: prepareAttachmentTransport,
                waitForConnection: waitForChatConnection,
                watchDelivery: watchDelivery
            ),
            resendMessage: DefaultResendMessageUseCase(
                chat: chat,
                attachments: attachments,
                deliver: deliverTextMessage,
                prepareTransport: prepareAttachmentTransport,
                watchDelivery: watchDelivery,
                verifyDelivered: verifyMessageDelivered
            ),
            addAttachments: DefaultAddAttachmentsUseCase(chat: chat, attachments: attachments),
            removeAttachment: DefaultRemoveAttachmentUseCase(chat: chat, attachments: attachments),
            openAttachment: DefaultOpenAttachmentUseCase(chat: chat, waitForTransport: waitForTransport),
            endChat: DefaultEndChatUseCase(chat: chat),
            cameraPermission: DefaultCameraPermissionRepository(provider: AVCameraPermissionProvider())
        )
    }
}
