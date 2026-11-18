import SwiftUI
import UIKit

struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> SwipeBackController {
        SwipeBackController()
    }

    func updateUIViewController(_: SwipeBackController, context _: Context) {}
}
