import Filament
import SwiftUI

/// Filament notification without a close button: a signal notice for a `state` (inline above the input, or a
/// floating `.Toast` with Filament's elevation shadow), otherwise the default (neutral) inline notification on a
/// blurred backdrop.
struct ChatNotice: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let text: String
    var state: DlsNotificationStateVariant?
    var shape: DlsNotificationVariant = .Inline
    var icon: DlsAsset = .informationCircleFill

    /// Filament's `notification/borderradius`; its size token is not public.
    private static let cornerRadius: CGFloat = 12

    var body: some View {
        if let state {
            DlsNotification(
                labelString: text,
                notificationState: state,
                shape: shape,
                icon: icon,
                hideNotification: .constant(false),
                showCloseButton: false,
                notificationBodyforAccessibility: text
            )
        } else {
            DlsNotification(
                labelString: text,
                notificationColor: themeManager.current.notification.color.defaultColor,
                shape: .Inline,
                icon: icon,
                hideNotification: .constant(false),
                showCloseButton: false,
                notificationBodyforAccessibility: text
            )
            .background {
                Color.clear
                    .dlsBlurredBackground(themeManager.current.colorTokens.container.background.translucent.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
            }
        }
    }
}
