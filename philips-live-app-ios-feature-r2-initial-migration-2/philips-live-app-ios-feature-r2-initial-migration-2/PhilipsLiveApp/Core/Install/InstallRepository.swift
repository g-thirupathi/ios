import Foundation

protocol InstallRepository {
    /// Whether this is the first launch since the app was installed, for the first time or again.
    var isFirstLaunchSinceInstall: Bool { get }
    func markLaunched()
    /// Removes what an earlier install left behind: the Keychain survives uninstalling the app.
    func clearLeftoverData() throws
}

struct DefaultInstallRepository: InstallRepository {
    private let marker: InstallMarkerLocalDataSource
    private let preferences: PreferencesLocalDataSource

    init(marker: InstallMarkerLocalDataSource, preferences: PreferencesLocalDataSource) {
        self.marker = marker
        self.preferences = preferences
    }

    var isFirstLaunchSinceInstall: Bool {
        !marker.hasMarker
    }

    func markLaunched() {
        marker.setMarker()
    }

    func clearLeftoverData() throws {
        try preferences.removeAllValues()
    }
}
