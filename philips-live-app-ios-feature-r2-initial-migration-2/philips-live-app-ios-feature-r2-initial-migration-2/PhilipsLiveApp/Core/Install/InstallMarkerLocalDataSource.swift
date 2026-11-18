import Foundation

protocol InstallMarkerLocalDataSource {
    var hasMarker: Bool { get }
    func setMarker()
}

/// Kept in `UserDefaults`, which is erased with the app, unlike the Keychain.
struct UserDefaultsInstallMarkerLocalDataSource: InstallMarkerLocalDataSource {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasMarker: Bool {
        defaults.string(forKey: SecureStorage.installMarkerKey) != nil
    }

    func setMarker() {
        defaults.set(UUID().uuidString, forKey: SecureStorage.installMarkerKey)
    }
}
