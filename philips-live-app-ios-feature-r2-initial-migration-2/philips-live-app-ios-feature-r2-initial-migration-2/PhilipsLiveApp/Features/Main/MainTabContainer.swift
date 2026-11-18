import Filament
import SwiftUI

/// The app's tab shell. The chat is pushed above it by the root navigation stack, which covers the tab bar, because
/// `DlsBottomTabBar` draws over its content and ignores the keyboard safe area.
struct MainTabContainer: View {
    let makeHomeViewModel: () -> HomeViewModel
    let onOpenChat: () -> Void

    @State private var selection = MainTab.home

    var body: some View {
        DlsBottomTabBar(selection: $selection) {
            HomeScreen(viewModel: makeHomeViewModel(), onOpenChat: onOpenChat)
                .tabItem(for: MainTab.home)
            SettingsScreen()
                .tabItem(for: MainTab.settings)
        }
    }
}
