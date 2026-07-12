@testable import HackersPub
import SwiftUI
import Testing
import UIKit

func feedViewport(
    anchors: [(String, CGFloat)],
    isAtTop: Bool
) -> FeedViewportSnapshot<String> {
    FeedViewportSnapshot(
        visibleAnchors: anchors.map { FeedViewportAnchor(id: $0.0, offset: $0.1) },
        isAtTop: isAtTop
    )
}

func feedFreshnessContext(
    restorationSequence: Int?,
    pendingRestorationSequence: Int?,
    layoutRevision: Int,
    frameVersion: Int,
    scrollMetricGeneration: Int
) -> FeedScrollFreshnessContext {
    FeedScrollFreshnessContext(
        restorationSequence: restorationSequence,
        pendingRestorationSequence: pendingRestorationSequence,
        layoutRevision: layoutRevision,
        frameVersion: frameVersion,
        scrollMetricGeneration: scrollMetricGeneration
    )
}

func feedRowMeasurement(
    frame: CGRect,
    layoutRevision: Int,
    measurementEpoch: Int = 0,
    appearanceGeneration: Int = 0
) -> FeedAnchorRowGeometry {
    FeedAnchorRowGeometry(
        frame: frame,
        layoutRevision: layoutRevision,
        measurementEpoch: measurementEpoch,
        appearanceGeneration: appearanceGeneration
    )
}

@MainActor
final class ManualFeedScrollCommandFrameScheduler: FeedScrollCommandFrameScheduling {
    private var pendingOperation: FeedScrollCommandFrameOperation?
    private var commandFrameGeneration = 0
    private var commandFrameTimestamp: TimeInterval = 0
    private var eligibleFrameGeneration: Int?
    private(set) var scheduleCount = 0

    var hasPendingOperation: Bool {
        pendingOperation != nil
    }

    func schedule(_ operation: @escaping FeedScrollCommandFrameOperation) {
        scheduleCount &+= 1
        pendingOperation = operation
        if eligibleFrameGeneration == nil {
            eligibleFrameGeneration = commandFrameGeneration + 2
        }
    }

    func cancel() {
        pendingOperation = nil
        eligibleFrameGeneration = nil
    }

    func advanceFrame() {
        guard let pendingOperation else { return }

        commandFrameGeneration &+= 1
        commandFrameTimestamp += 1
        guard commandFrameGeneration >= eligibleFrameGeneration ?? .max else { return }

        self.pendingOperation = nil
        eligibleFrameGeneration = nil
        pendingOperation(
            FeedScrollCommandFrame(
                generation: commandFrameGeneration,
                timestamp: commandFrameTimestamp
            )
        )
    }
}

@MainActor
func waitForDisplayFrames(until predicate: () -> Bool) async -> Bool {
    for _ in 0 ..< 12 {
        if predicate() {
            return true
        }
        await awaitNextDisplayFrame()
    }
    return predicate()
}

@MainActor
func awaitNextDisplayFrame() async {
    await withCheckedContinuation { continuation in
        DisplayLinkAwaiter(continuation: continuation).schedule()
    }
}

@MainActor
func firstScrollView(in view: UIView) -> UIScrollView? {
    if let scrollView = view as? UIScrollView {
        return scrollView
    }
    return view.subviews.lazy.compactMap(firstScrollView).first
}

@MainActor
final class DisplayLinkAwaiter: NSObject {
    private let continuation: CheckedContinuation<Void, Never>
    private var displayLink: CADisplayLink?

    init(continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func schedule() {
        let displayLink = CADisplayLink(target: self, selector: #selector(displayFrameDidFire))
        self.displayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    @objc private func displayFrameDidFire() {
        displayLink?.invalidate()
        displayLink = nil
        continuation.resume()
    }
}
