import SwiftUI

/// Positions reported by the list, all in the scroll view's coordinate space as drawn (the viewport's top edge is 0).
struct ChatScrollMetrics: Equatable {
    /// The scroll target at the bottom, inside the lazy stack: unknown while it isn't laid out.
    var anchorTop: CGFloat?
    /// The oldest row, padding included, inside the lazy stack: unknown while it isn't laid out.
    var oldestTop: CGFloat?
    /// The oldest end of the content, outside the lazy stack: always laid out, it reports on every scroll frame,
    /// which is when the distance to the bottom is checked.
    var endTop: CGFloat?
    var viewportHeight: CGFloat?

    var isMeasured: Bool {
        viewportHeight != nil
    }

    /// The list is flipped, so at the bottom the anchor rests on the viewport's bottom edge. The offset alone can't
    /// tell: after a long move SwiftUI can still draw the rows where it estimated them, with a gap below the newest.
    var isAnchorAtBottom: Bool {
        guard let anchorTop, let viewportHeight else { return false }
        return abs(viewportHeight - anchorTop) <= Self.bottomTolerance
    }

    /// At the top the oldest row's padding reaches the viewport's top edge, as drawn, like the anchor at the bottom.
    var isOldestAtTop: Bool {
        guard let oldestTop else { return false }
        return abs(oldestTop) <= Self.topTolerance
    }

    /// The anchor's own height plus layout rounding.
    private static let bottomTolerance: CGFloat = 2
    /// The oldest row reads a point inside the content's end when it is there.
    private static let topTolerance: CGFloat = 2
}
