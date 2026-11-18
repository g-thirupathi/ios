import SafariServices
import SwiftUI

/// Safari dismisses itself on Done and SwiftUI clears the sheet binding from that; clearing it again from a delegate
/// would dismiss whatever sheet is presented underneath as well.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {}
}
