import Filament
import SwiftUI

struct DarkThemeContainer<Content: View>: View {
    @StateObject private var darkTheme: DlsThemeManager
    private let forcesDarkAppearance: Bool
    private let content: Content

    init(appTheme: DlsTheme, forcesDarkAppearance: Bool, @ViewBuilder content: () -> Content) {
        self.forcesDarkAppearance = forcesDarkAppearance
        _darkTheme = StateObject(wrappedValue: DlsThemeManager(
            appTheme.baseColor,
            colorScheme: .dark,
            expressive: appTheme.expressive,
            multiplier: appTheme.multiplier,
            fontScaling: appTheme.fontTokens.scaling,
            density: appTheme.density
        ))
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(darkTheme)
            .preferredColorScheme(forcesDarkAppearance ? .dark : nil)
    }
}
