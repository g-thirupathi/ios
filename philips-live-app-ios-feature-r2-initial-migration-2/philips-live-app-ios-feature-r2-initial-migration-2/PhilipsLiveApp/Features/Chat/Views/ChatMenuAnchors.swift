import SwiftUI

/// Where the chat's menus open: below the header, and above the chat input.
struct ChatMenuAnchors {
    var header: Anchor<CGRect>?
    var aboveInput: Anchor<CGRect>?
}
