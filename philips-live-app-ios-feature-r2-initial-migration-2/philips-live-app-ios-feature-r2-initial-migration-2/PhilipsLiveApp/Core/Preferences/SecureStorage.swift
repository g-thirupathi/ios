import Foundation

/// Names R1 fixed for what the app keeps on the device across installs. They must not follow the bundle identifier or
/// change: a different name would leave the data R1 saved unreadable after the update.
enum SecureStorage {
    static let keychainService = "com.philips.serviceliveapp.dev.secure-storage"
    static let installMarkerKey = "philipslive:installMarker"
}
