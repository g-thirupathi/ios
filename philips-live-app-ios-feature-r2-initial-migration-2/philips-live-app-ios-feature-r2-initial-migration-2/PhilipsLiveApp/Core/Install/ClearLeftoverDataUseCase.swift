import OSLog

protocol ClearLeftoverDataUseCase {
    func execute()
}

/// The first launch after installing starts from nothing instead of from what an earlier install left in the Keychain.
/// The launch is marked even if clearing failed, so that a later retry never clears data saved in the meantime.
struct DefaultClearLeftoverDataUseCase: ClearLeftoverDataUseCase {
    private let install: InstallRepository
    private let logger = Logger(category: "ClearLeftoverDataUseCase")

    init(install: InstallRepository) {
        self.install = install
    }

    func execute() {
        guard install.isFirstLaunchSinceInstall else { return }
        do {
            try install.clearLeftoverData()
        } catch {
            logger.error("Clearing data left by an earlier install failed: \(error)")
        }
        install.markLaunched()
    }
}
