import Foundation
import ObjectiveC.runtime

/// Read from any thread by Foundation and SwiftUI string lookups, so guarded by a lock instead of an actor.
nonisolated enum RoutingState {
    static let lock = NSLock()
    /// The selected language first, then the languages it falls back to before English.
    nonisolated(unsafe) static var routed: [Bundle] = []
    nonisolated(unsafe) static var fallback: Bundle?
    static let missingTranslation = "\u{FFFD}__missing__\u{FFFD}"
}
