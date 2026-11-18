import Filament
import SwiftUI

extension View {
    /// Pins this view to a dark copy of the app theme (same base colour, density, multiplier and font scaling),
    /// for screens designed dark in both appearances.
    ///
    /// The forced dark appearance covers the whole presentation, including sheets and screens pushed from this view;
    /// pass `false` to keep only the dark theme and leave the system appearance alone.
    func darkTheme(forcesDarkAppearance: Bool = true) -> some View {
        modifier(DarkThemeModifier(forcesDarkAppearance: forcesDarkAppearance))
    }
}

private struct DarkThemeModifier: ViewModifier {
    @EnvironmentObject private var appTheme: DlsThemeManager

    let forcesDarkAppearance: Bool

    func body(content: Content) -> some View {
        DarkThemeContainer(appTheme: appTheme.current, forcesDarkAppearance: forcesDarkAppearance) { content }
    }
}
