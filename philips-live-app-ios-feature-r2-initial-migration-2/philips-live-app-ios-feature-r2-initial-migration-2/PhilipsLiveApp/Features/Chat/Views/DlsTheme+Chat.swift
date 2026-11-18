import Filament
import SwiftUI

extension DlsTheme {
    /// The side of an agent's avatar.
    var chatAvatarSide: CGFloat {
        avatar.size.s32.height
    }

    /// How far agent bubbles sit from the leading edge to leave room for the avatar and its gap.
    var chatAvatarInset: CGFloat {
        chatAvatarSide + dimensionTokens.size05
    }
}
