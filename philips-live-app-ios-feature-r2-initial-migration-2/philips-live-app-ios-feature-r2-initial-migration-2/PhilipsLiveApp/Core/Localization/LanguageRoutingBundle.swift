import Foundation
import ObjectiveC.runtime

final nonisolated class LanguageRoutingBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        let (routed, fallback) = RoutingState.lock.withLock { (RoutingState.routed, RoutingState.fallback) }
        guard !routed.isEmpty else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        for bundle in routed {
            let translated = bundle.localizedString(
                forKey: key,
                value: RoutingState.missingTranslation,
                table: tableName
            )
            if translated != RoutingState.missingTranslation {
                return translated
            }
        }
        return fallback?.localizedString(forKey: key, value: value, table: tableName)
            ?? super.localizedString(forKey: key, value: value, table: tableName)
    }
}
