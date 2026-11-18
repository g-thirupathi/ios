import Foundation

protocol AppConfigurationProvider {
    func chatConfiguration(for country: SupportCountry) -> ChatConfiguration?
}

/// Reads build-time values baked into Info.plist by `xcodegen generate`
struct InfoPlistAppConfigurationProvider: AppConfigurationProvider {
    private static let chatConfigurationsKey = "GenesysChatConfigurations"
    private static let defaultEntryKey = "default"
    private static let sharedEntryKey = "META"

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func chatConfiguration(for country: SupportCountry) -> ChatConfiguration? {
        let entries = bundle.object(forInfoDictionaryKey: Self.chatConfigurationsKey) as? [String: [String: String]]
        let defaultEntry = entries?[Self.defaultEntryKey]
        let entry = entries?[Self.entryKey(for: country)]

        var domain = value(entry?["Domain"])
        if country.usesDefaultChatDomain, domain == nil {
            domain = value(defaultEntry?["Domain"])
        }
        guard let deploymentId = value(entry?["DeploymentId"]), let domain else {
            return nil
        }
        return ChatConfiguration(
            deploymentId: deploymentId,
            domain: domain,
            userCountry: country.sharesMetaChat ? country.rawValue : nil
        )
    }

    private static func entryKey(for country: SupportCountry) -> String {
        if country == .india {
            defaultEntryKey
        } else if country.sharesMetaChat {
            sharedEntryKey
        } else {
            country.rawValue
        }
    }

    /// Unset variables reach the plist empty or as an unresolved `$(...)` reference.
    private func value(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty, !raw.contains("$") else {
            return nil
        }
        return raw
    }
}
