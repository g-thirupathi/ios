import SwiftUI

extension View {
    /// Keeps the edge swipe-back gesture working on a screen that hides the system navigation bar and draws its own.
    func swipeBackEnabled() -> some View {
        background(SwipeBackEnabler())
    }
}
