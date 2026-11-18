import SwiftUI
import UIKit

/// Positions the chat list. The list is flipped: its content runs newest first from the input up, so the bottom is
/// the start of the content, an exact offset that the list keeps by itself when it changes height (the keyboard, a
/// notice above the input). Scrolls to the bottom, and to the oldest message for the status bar's tap.
final class ChatScroller {
    private(set) var metrics = ChatScrollMetrics()
    var tailItemCount = 0
    weak var locator: ScrollViewLocator.LocatorView?
    private(set) var isSettling = false

    private weak var scrolledOnAppear: UIScrollView?
    private weak var adoptedScrollView: UIScrollView?
    private var rangeObservations: [NSKeyValueObservation] = []
    private var task: Task<Void, Never>?
    private let animator = OffsetAnimator()
    private let maxAttempts = 10
    private let requiredPlacedChecks = 2
    private let retryInterval: Duration = .milliseconds(100)
    /// A couple of frames, for the layout after a scroll to reach the metrics.
    private let layoutDelay: Duration = .milliseconds(50)
    /// Offsets land on whole pixels.
    private let offsetTolerance: CGFloat = 1

    /// Close enough to the bottom for messages from others to be followed.
    var isWithinNearDistance: Bool {
        guard let distance = distanceFromBottom else { return false }
        return distance <= ChatScroll.nearDistance
    }

    /// While a scroll to the bottom is settling (the opening one included) the list counts as near, so the
    /// scroll-to-latest button doesn't flash in on the way there.
    func isNearBottom(wasNear: Bool) -> Bool {
        guard !isSettling else { return true }
        guard let distance = distanceFromBottom else { return wasNear }
        return distance <= (wasNear ? ChatScroll.awayDistance : ChatScroll.nearDistance)
    }

    /// Not `isTracking`: it can stay set after a tap, and the scroll view reaches under the input panel.
    var isUserScrolling: Bool {
        guard let scrollView = locator?.scrollView else { return false }
        return scrollView.isDragging || scrollView.isDecelerating
    }

    func update(_ metrics: ChatScrollMetrics) {
        self.metrics = metrics
        adoptScrollView()
    }

    /// Once per scroll view: coming back to the screen, e.g. from a full-screen cover, keeps the position.
    func scrollToBottomOnAppear(_ proxy: ScrollViewProxy) {
        let scrollView = locator?.scrollView
        guard scrollView == nil || scrollView !== scrolledOnAppear else { return }
        scrolledOnAppear = scrollView
        scrollToBottom(proxy, animated: false)
    }

    /// Animated, the list moves to the bottom frame by frame; either way the proxy then places it until the anchor
    /// rests on the bottom edge. The first move waits one turn so newly inserted rows are laid out. A fling still
    /// coasting is stopped first, and the user scrolling ends the scroll.
    func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        task?.cancel()
        isSettling = true
        stopMomentum()
        task = Task {
            await Task.yield()
            if animated, !isUserScrolling, let scrollView = locator?.scrollView {
                // Each frame starts from wherever the list is, so SwiftUI's own corrections for rows re-estimated on
                // the way stay.
                await animator.chase(scrollView, curve: .easeIn) { [weak scrollView] in
                    scrollView.map { -$0.adjustedContentInset.top }
                }
                try? await Task.sleep(for: layoutDelay)
            }
            await settle(
                until: { metrics.isAnchorAtBottom },
                place: { proxy.scrollTo(ChatScroll.bottomAnchorId, anchor: .top) }
            )
            guard !Task.isCancelled else { return }
            isSettling = false
        }
    }

    /// The oldest message is at the visual top, as far as the lazy stack has estimated: measuring the rows there moves
    /// that end, so the scroll follows it, and the proxy then places the oldest row.
    func scrollToOldest(_ proxy: ScrollViewProxy) {
        task?.cancel()
        animator.stop()
        isSettling = false
        stopMomentum()
        task = Task {
            guard let scrollView = locator?.scrollView else { return }
            await animator.chase(scrollView, curve: .easeOut) { [weak scrollView] in
                guard let scrollView else { return nil }
                return self.oldestEndOffset(of: scrollView)
            }
            try? await Task.sleep(for: layoutDelay)
            await settle(
                until: { metrics.isOldestAtTop },
                place: { proxy.scrollTo(ChatScroll.oldestAnchorId, anchor: .bottom) }
            )
        }
    }

    func cancel() {
        task?.cancel()
        animator.stop()
        isSettling = false
    }

    /// The offset alone can't tell an end is reached: after a long move SwiftUI can still draw the rows where it
    /// estimated them, with a gap at the end. The proxy closes it, as it places by SwiftUI's own layout. Done once
    /// placed on two checks in a row, as measuring the rows there can still move the end.
    private func settle(until isPlaced: () -> Bool, place: () -> Void) async {
        var placedChecks = 0
        for _ in 0 ..< maxAttempts {
            guard !Task.isCancelled, !isUserScrolling else { return }
            if isPlaced() {
                placedChecks += 1
                if placedChecks == requiredPlacedChecks {
                    return
                }
            } else {
                placedChecks = 0
                place()
            }
            try? await Task.sleep(for: retryInterval)
        }
    }

    /// UIKit pulls an offset past either end back only once the list is touched. A resize can leave the list there,
    /// as when the keyboard closes at the top, and so can SwiftUI putting back an offset it had before, leaving a gap
    /// at that end; so the offset is brought back. A finger on the list, its bounce or a scroll still running is left
    /// to finish.
    private func keepInRange(_ scrollView: UIScrollView) {
        guard !scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating, !animator.isRunning
        else { return }
        let bottom = -scrollView.adjustedContentInset.top
        let top = oldestEndOffset(of: scrollView)
        let offset = scrollView.contentOffset.y
        guard offset > top + offsetTolerance || offset < bottom - offsetTolerance else { return }
        scrollView.contentOffset.y = min(max(offset, bottom), top)
    }

    /// Past the bottom, as when SwiftUI has just moved the list, counts as at it.
    private var distanceFromBottom: CGFloat? {
        locator?.scrollView.map { max($0.contentOffset.y + $0.adjustedContentInset.top, 0) }
    }

    /// SwiftUI can hand out a different scroll view, e.g. after the list is rebuilt.
    private func adoptScrollView() {
        guard let scrollView = locator?.scrollView, scrollView !== adoptedScrollView else { return }
        adoptedScrollView = scrollView
        // Flipped, the status bar's scroll to the top would land on the newest message; `StatusBarTapView` takes
        // the tap instead.
        scrollView.scrollsToTop = false
        rangeObservations = [
            scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
                MainActor.assumeIsolated { self?.keepInRange(scrollView) }
            },
            scrollView.observe(\.contentSize) { [weak self] scrollView, _ in
                MainActor.assumeIsolated { self?.keepInRange(scrollView) }
            },
            // The layer, not the view: SwiftUI resizes the view without going through its observable `bounds`.
            scrollView.layer.observe(\.bounds) { [weak self, weak scrollView] _, _ in
                MainActor.assumeIsolated {
                    guard let scrollView else { return }
                    self?.keepInRange(scrollView)
                }
            },
        ]
    }

    private func oldestEndOffset(of scrollView: UIScrollView) -> CGFloat {
        let inset = scrollView.adjustedContentInset
        return max(scrollView.contentSize.height + inset.bottom - scrollView.bounds.height, -inset.top)
    }

    private func stopMomentum() {
        guard let scrollView = locator?.scrollView, scrollView.isDecelerating else { return }
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
    }
}

private extension ChatScroller {
    enum Curve {
        /// Starts already moving and gains speed up to the target, so the last stretch, where SwiftUI still corrects
        /// rows it had estimated, passes in a frame or two.
        case easeIn
        /// The ease-in reversed: starts at its fastest and slows down, arriving gently.
        case easeOut
    }

    /// Moves a scroll view's offset frame by frame, over a time that grows with the distance, and stops when a finger
    /// takes the list. Each frame covers the curve's share of what remains, from wherever the list is and to the
    /// target read anew, so corrections by SwiftUI and a target still moving are spread over the time left.
    final class OffsetAnimator: NSObject {
        private var link: CADisplayLink?
        private weak var scrollView: UIScrollView?
        private var curve = Curve.easeIn
        private var start: CFTimeInterval = 0
        private var duration: CFTimeInterval = 0
        private var progress: CGFloat = 0
        private var target: (() -> CGFloat?)?
        private var finished: CheckedContinuation<Void, Never>?
        /// An ease's speed at its slow end (an ease-in's start, an ease-out's arrival) as a share of its average: from
        /// rest, the first stretch drags by. Its fast end is 1.57 times the average, as fast as a sine ease's.
        private let slowEndSpeed: CGFloat = 0.43
        /// For a screen or less.
        private let minimumDuration: CFTimeInterval = 0.3
        /// Added each time the distance doubles beyond a screen.
        private let durationPerDoubling: CFTimeInterval = 0.075
        private let maximumDuration: CFTimeInterval = 0.6
        /// The longest a chase runs, holding the target after its time included.
        private let chaseLimit: CFTimeInterval = 1.5
        /// Offsets land on whole pixels, so closer than this is the target.
        private let restDistance: CGFloat = 1
        private let frameRates = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)

        var isRunning: Bool {
            link != nil
        }

        func stop() {
            link?.invalidate()
            link = nil
            target = nil
            finished?.resume()
            finished = nil
        }

        func chase(_ scrollView: UIScrollView, curve: Curve, target: @escaping () -> CGFloat?) async {
            stop()
            guard let goal = target() else { return }
            let distance = abs(goal - scrollView.contentOffset.y)
            guard distance >= restDistance else {
                scrollView.contentOffset.y = goal
                return
            }
            self.scrollView = scrollView
            self.curve = curve
            self.target = target
            progress = 0
            start = CACurrentMediaTime()
            let screens = max(Double(distance / max(scrollView.bounds.height, 1)), 1)
            duration = min(minimumDuration + durationPerDoubling * log2(screens), maximumDuration)
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.preferredFrameRateRange = frameRates
            link.add(to: .main, forMode: .common)
            self.link = link
            await withCheckedContinuation { finished = $0 }
        }

        @objc private func step(_ link: CADisplayLink) {
            guard let scrollView, let target = target?() else { return stop() }
            switch scrollView.panGestureRecognizer.state {
                case .began, .changed:
                    return stop()
                default: break
            }
            let displacement = scrollView.contentOffset.y - target
            let elapsed = link.targetTimestamp - start
            guard elapsed < duration else {
                // SwiftUI can still move the list in the layout pass right after the last step, even past the end;
                // the target is held until a frame finds the list there.
                scrollView.contentOffset.y = target
                if abs(displacement) < restDistance || elapsed > chaseLimit {
                    stop()
                }
                return
            }
            let covered = eased(CGFloat(elapsed / duration))
            scrollView.contentOffset.y -= displacement * (covered - progress) / (1 - progress)
            progress = covered
        }

        /// The share of the distance covered after `fraction` of the time.
        private func eased(_ fraction: CGFloat) -> CGFloat {
            switch curve {
                case .easeIn: speedingUp(fraction)
                case .easeOut: 1 - speedingUp(1 - fraction)
            }
        }

        private func speedingUp(_ fraction: CGFloat) -> CGFloat {
            slowEndSpeed * fraction + (1 - slowEndSpeed) * fraction * fraction
        }
    }
}
