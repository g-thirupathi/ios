import SwiftUI
import UIKit

/// Gives access to the `UIScrollView` enclosing the view it is attached to inside a `ScrollView`, for moving it by a
/// number of points, which `ScrollViewProxy` can't do on iOS 16. The scroll view is looked up on each use, because
/// SwiftUI can move the view around after creating it.
struct ScrollViewLocator: UIViewRepresentable {
    let onCreate: (LocatorView) -> Void

    func makeUIView(context _: Context) -> LocatorView {
        let view = LocatorView()
        onCreate(view)
        return view
    }

    func updateUIView(_: LocatorView, context _: Context) {}

    final class LocatorView: UIView {
        var scrollView: UIScrollView? {
            sequence(first: self as UIView, next: \.superview).lazy.compactMap { $0 as? UIScrollView }.first
        }
    }
}
