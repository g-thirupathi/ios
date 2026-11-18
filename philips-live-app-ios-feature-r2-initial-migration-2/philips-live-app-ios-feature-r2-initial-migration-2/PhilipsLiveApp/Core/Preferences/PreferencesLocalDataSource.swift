import Foundation
import Security

protocol PreferencesLocalDataSource {
    func string(forKey key: String) throws -> String?
    func set(_ value: String, forKey key: String) throws
    func removeValue(forKey key: String) throws
    /// Removes every value saved under this data source's name, whatever its protection.
    func removeAllValues() throws
    /// Removes every Keychain item the app can access, including the ones other components keep there.
    func wipeKeychain() throws
}

/// Layout matches R1 (service, account, UTF-8 data) so data survives the R1 -> R2 update. Items are found
/// whatever their protection, so ones R1 saved readable after the first unlock are read under any `protection`.
struct KeychainPreferencesLocalDataSource: PreferencesLocalDataSource {
    enum Protection {
        /// As R1 saved everything: readable once the device was unlocked after starting, e.g. at a background launch.
        case afterFirstUnlock
        /// Readable only while the device is unlocked.
        case whileUnlocked
    }

    private let service: String
    private let accessibility: CFString

    init(service: String = SecureStorage.keychainService, protection: Protection = .afterFirstUnlock) {
        self.service = service
        accessibility = switch protection {
            case .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .whileUnlocked: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
    }

    /// An item saved with another protection, by R1 or before the protection changed, is moved to this one.
    func string(forKey key: String) throws -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
        guard let item = result as? [String: Any] else { return nil }
        if item[kSecAttrAccessible as String] as? String != accessibility as String {
            // Best effort: a failed move is tried again on the next read.
            _ = SecItemUpdate(
                baseQuery(forKey: key) as CFDictionary,
                [kSecAttrAccessible as String: accessibility] as CFDictionary
            )
        }
        guard let data = item[kSecValueData as String] as? Data, let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    func set(_ value: String, forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: accessibility,
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    func removeValue(forKey key: String) throws {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    func removeAllValues() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    func wipeKeychain() throws {
        let classes = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity,
        ]
        for itemClass in classes {
            let status = SecItemDelete([kSecClass as String: itemClass] as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError(status: status)
            }
        }
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
