import Filament
import SwiftUI

/// Filament's secondary pill button with only the arrow: `DlsButton`'s icon-only init uses square icon padding,
/// while the design keeps the round button's text padding, which `DlsButtonStyle` applies to a custom label.
struct ScrollToLatestButton: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let action: () -> Void

    var body: some View {
        let tokens = themeManager.current.button
        Button(action: action) {
            DlsIcon(.arrowTailDown, size: tokens.size.icon)
        }
        .buttonStyle(DlsButtonStyle(
            labelText: "",
            fullWidth: false,
            iconAsset: nil,
            iconSize: 0,
            image: nil,
            imagePos: .leading,
            sizes: tokens.size,
            colors: tokens.color.secondary,
            fontToken: tokens.typography.label,
            tokens: tokens,
            shape: .round,
            pressedSound: nil
        ))
        // Filament's secondary fill is a 6% tint, too faint over messages: back it with Filament's blurred
        // translucent surface in the neutral tertiary colour.
        .background {
            Color.clear
                .dlsBlurredBackground(themeManager.current.colorTokens.container.background.translucent.tertiary)
                .clipShape(Capsule())
        }
    }
}
