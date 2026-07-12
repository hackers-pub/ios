import SwiftUI

struct FeedViewportAnchor<ID: Hashable>: Equatable {
    let id: ID
    let offset: CGFloat
}

struct FeedViewportSnapshot<ID: Hashable>: Equatable {
    let visibleAnchors: [FeedViewportAnchor<ID>]
    let isAtTop: Bool

    init(
        visibleAnchors: [FeedViewportAnchor<ID>] = [],
        isAtTop: Bool = true
    ) {
        self.visibleAnchors = visibleAnchors
        self.isAtTop = isAtTop
    }

    var primaryAnchor: FeedViewportAnchor<ID>? {
        visibleAnchors.first
    }
}

enum FeedScrollOffsetAdjustment {
    static func targetScrollPositionY(
        metrics: FeedScrollMetrics,
        currentAnchorOffset: CGFloat,
        desiredAnchorOffset: CGFloat
    ) -> CGFloat {
        let unclamped = metrics.contentOffsetY
            + metrics.topInset
            + currentAnchorOffset
            - desiredAnchorOffset
        let maximumLogicalY = max(
            0,
            metrics.contentHeight
                - metrics.viewportHeight
                + metrics.topInset
                + metrics.bottomInset
        )
        return min(max(0, unclamped), maximumLogicalY)
    }
}

struct FeedScrollRestorationAttemptTracker: Equatable {
    private(set) var attemptCount = 0
    private(set) var requiresVisibleRetry = false

    mutating func reset() {
        attemptCount = 0
        requiresVisibleRetry = false
    }

    mutating func recordIssuedCommand() {
        attemptCount += 1
        requiresVisibleRetry = attemptCount >= 3
    }

    var mayIssue: Bool {
        !requiresVisibleRetry
    }

    mutating func requireVisibleRetry() {
        requiresVisibleRetry = true
    }
}

struct FeedScrollMetricFence: Equatable {
    private(set) var generation = 0
    private(set) var awaitingGeneration: Int?

    var allowsCommand: Bool {
        awaitingGeneration == nil || generation > awaitingGeneration!
    }

    mutating func observeFreshMetrics() {
        generation &+= 1
    }

    mutating func recordIssuedCommand() {
        awaitingGeneration = generation
    }

    mutating func reset() {
        awaitingGeneration = nil
    }

    mutating func invalidate() {
        generation &+= 1
        awaitingGeneration = nil
    }
}

struct FeedScrollCommandToken: Equatable {
    let sequence: Int
    let attempt: Int
    let awaitingMetricGeneration: Int
}

enum FeedScrollWatchdog {
    static func shouldRequireRetry(
        token: FeedScrollCommandToken,
        pendingSequence: Int?,
        attemptCount: Int,
        awaitingMetricGeneration: Int?,
        scrollMetricGeneration: Int
    ) -> Bool {
        token.sequence == pendingSequence
            && token.attempt == attemptCount
            && token.awaitingMetricGeneration == awaitingMetricGeneration
            && token.awaitingMetricGeneration == scrollMetricGeneration
    }
}

/// Captures semantic rows and their measured viewport offsets before a prepend.
/// A restoration always belongs to one layout sequence, so a rapid later
/// prepend cannot consume frames reported for an earlier layout.
struct FeedScrollAnchorPolicy<ID: Hashable> {
    struct Restoration: Equatable {
        let id: ID
        let offset: CGFloat
        let sequence: Int
    }

    private struct PendingCapture {
        let primaryAnchor: FeedViewportAnchor<ID>
        let visibleAnchors: [FeedViewportAnchor<ID>]
        let orderedIDs: [ID]
    }

    private var pendingCapture: PendingCapture?
    private var nextSequence = 0

    mutating func captureBeforePrepending(
        viewport: FeedViewportSnapshot<ID>,
        existingIDs: [ID]
    ) {
        pendingCapture = nil
        guard !viewport.isAtTop else { return }

        let existingIDSet = Set(existingIDs)
        let visibleAnchors = viewport.visibleAnchors.filter { existingIDSet.contains($0.id) }
        guard let primaryAnchor = visibleAnchors.first else { return }

        pendingCapture = PendingCapture(
            primaryAnchor: primaryAnchor,
            visibleAnchors: visibleAnchors,
            orderedIDs: existingIDs
        )
    }

    mutating func takeRestoration(availableIDs: [ID]) -> Restoration? {
        defer { pendingCapture = nil }
        guard let pendingCapture,
              let anchor = restorationAnchor(
                  from: pendingCapture,
                  availableIDs: Set(availableIDs)
              )
        else {
            return nil
        }

        nextSequence &+= 1
        return Restoration(id: anchor.id, offset: anchor.offset, sequence: nextSequence)
    }

    mutating func reset() {
        pendingCapture = nil
        nextSequence &+= 1
    }

    private func restorationAnchor(
        from capture: PendingCapture,
        availableIDs: Set<ID>
    ) -> FeedViewportAnchor<ID>? {
        if availableIDs.contains(capture.primaryAnchor.id) {
            return capture.primaryAnchor
        }

        guard let primaryIndex = capture.orderedIDs.firstIndex(of: capture.primaryAnchor.id) else {
            return nil
        }
        let measuredOffsets = Dictionary(
            capture.visibleAnchors.map { ($0.id, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )

        for distance in 1 ..< capture.orderedIDs.count {
            let followingIndex = primaryIndex + distance
            if followingIndex < capture.orderedIDs.count {
                let followingID = capture.orderedIDs[followingIndex]
                if availableIDs.contains(followingID) {
                    return FeedViewportAnchor(
                        id: followingID,
                        offset: measuredOffsets[followingID] ?? capture.primaryAnchor.offset
                    )
                }
            }

            let precedingIndex = primaryIndex - distance
            if precedingIndex >= 0 {
                let precedingID = capture.orderedIDs[precedingIndex]
                if availableIDs.contains(precedingID) {
                    return FeedViewportAnchor(
                        id: precedingID,
                        offset: measuredOffsets[precedingID] ?? capture.primaryAnchor.offset
                    )
                }
            }
        }

        return nil
    }
}

struct FeedScrollMetrics: Equatable {
    let contentOffsetY: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat

    init(
        contentOffsetY: CGFloat,
        topInset: CGFloat,
        bottomInset: CGFloat = 0,
        contentHeight: CGFloat,
        viewportHeight: CGFloat
    ) {
        self.contentOffsetY = contentOffsetY
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.contentHeight = contentHeight
        self.viewportHeight = viewportHeight
    }
}
