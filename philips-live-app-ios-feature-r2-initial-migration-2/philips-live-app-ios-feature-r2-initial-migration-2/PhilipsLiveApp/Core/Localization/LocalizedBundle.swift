import Foundation
import ObjectiveC.runtime

enum LocalizedBundle {
    static func route(to folders: [String]) {
        let bundles = folders.compactMap { folder in
            Bundle.main.path(forResource: folder, ofType: "lproj").flatMap(Bundle.init(path:))
        }
        RoutingState.lock.withLock { RoutingState.routed = bundles }
        installIfNeeded()
    }

    private static var isInstalled = false

    private static func installIfNeeded() {
        guard !isInstalled else { return }
        let fallbackFolder = Bundle.main.developmentLocalization ?? AppLanguage.default.rawValue
        let fallback = Bundle.main.path(forResource: fallbackFolder, ofType: "lproj").flatMap(Bundle.init(path:))
        RoutingState.lock.withLock { RoutingState.fallback = fallback }
        object_setClass(Bundle.main, LanguageRoutingBundle.self)
        isInstalled = true
    }
}
