import Filament
import SwiftUI

@main
struct PhilipsLiveApp: App {
    @StateObject private var themeManager = DlsThemeManager(.blue)
    @StateObject private var rootViewModel: RootViewModel

    private let dependencies: AppDependencies

    init() {
        let dependencies = AppDependencies()
        self.dependencies = dependencies
        _rootViewModel = StateObject(wrappedValue: dependencies.makeRootViewModel())
    }

    var body: some Scene {
        WindowGroup {
            RootContainer(dependencies: dependencies, viewModel: rootViewModel)
                .environment(\.locale, rootViewModel.locale)
                .task { await rootViewModel.observe() }
                .dlsTheme(themeManager)
        }
    }
}
