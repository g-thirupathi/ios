import UIKit

/// UIKit ties the pop gesture to the navigation bar being visible. While this screen is on top, the gesture gets a
/// delegate that allows it whenever there is a screen to go back to, and gets its own delegate back afterwards.
final class SwipeBackController: UIViewController, UIGestureRecognizerDelegate {
    private weak var previousDelegate: UIGestureRecognizerDelegate?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let gesture = navigationController?.interactivePopGestureRecognizer, gesture.delegate !== self else {
            return
        }
        previousDelegate = gesture.delegate
        gesture.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let gesture = navigationController?.interactivePopGestureRecognizer, gesture.delegate === self else {
            return
        }
        gesture.delegate = previousDelegate
    }

    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }
}
