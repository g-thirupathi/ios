import SwiftUI

extension View {
    /// Stops a scroll view that fits its content from bouncing. Before iOS 16.4 it keeps the system behaviour.
    @ViewBuilder
    func bouncesOnlyWhenScrollable() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}
