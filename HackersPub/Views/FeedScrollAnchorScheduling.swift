import SwiftUI
import UIKit

enum FeedScrollCommandPhase<ID: Hashable>: Equatable {
    case materialize(ID)
    case position(CGFloat)

    var identifier: String {
        switch self {
        case let .materialize(id): "materialize-\(id)"
        case let .position(positionY): "position-\(positionY)"
        }
    }
}

struct FeedScrollCommand<ID: Hashable>: Identifiable, Equatable {
    let sequence: Int
    let attempt: Int
    let phase: FeedScrollCommandPhase<ID>

    var id: String {
        "\(sequence)-\(attempt)-\(phase.identifier)"
    }
}

struct FeedScrollFreshnessContext: Equatable {
    let restorationSequence: Int?
    let pendingRestorationSequence: Int?
    let layoutRevision: Int
    let frameVersion: Int
    let scrollMetricGeneration: Int
}

struct FeedScrollCommandExecutionToken<ID: Hashable>: Equatable {
    let command: FeedScrollCommand<ID>
    let context: FeedScrollFreshnessContext
}

enum FeedScrollCommandFreshness {
    static func isCurrent(
        _ token: FeedScrollCommandExecutionToken<some Hashable>,
        context: FeedScrollFreshnessContext
    ) -> Bool {
        token.context == context
            && commandMatchesCurrentRestoration(
                token.command,
                context: context
            )
    }

    private static func commandMatchesCurrentRestoration(
        _ command: FeedScrollCommand<some Hashable>,
        context: FeedScrollFreshnessContext
    ) -> Bool {
        if command.sequence == 0 {
            return context.restorationSequence == nil
                && context.pendingRestorationSequence == nil
                && context.layoutRevision == 0
        }
        return context.restorationSequence == command.sequence
            && context.pendingRestorationSequence == command.sequence
            && context.layoutRevision == command.sequence
    }
}

enum FeedScrollAnchorLayoutRevision {
    static func value<ID: Hashable>(
        for restoration: FeedScrollAnchorPolicy<ID>.Restoration?
    ) -> Int {
        restoration?.sequence ?? 0
    }
}

struct FeedScrollMeasurementToken: Equatable {
    let context: FeedScrollFreshnessContext
}

enum FeedScrollMeasurementFreshness {
    static func isCurrent(
        _ token: FeedScrollMeasurementToken,
        context: FeedScrollFreshnessContext
    ) -> Bool {
        token.context == context
    }
}

/// Schedules one scroll command for the next physical display frame.
///
/// The scheduler invalidates its link before invoking its operation. If that
/// operation schedules another command, UIKit cannot deliver it until a later
/// display-link tick, which keeps materialization and exact positioning out of
/// the same frame.
struct FeedScrollCommandFrame: Equatable {
    let generation: Int
    let timestamp: TimeInterval
}

typealias FeedScrollCommandFrameOperation = @MainActor (FeedScrollCommandFrame) -> Void

@MainActor
protocol FeedScrollCommandFrameScheduling: AnyObject {
    func schedule(_ operation: @escaping FeedScrollCommandFrameOperation)
    func cancel()
}

@MainActor
final class FeedScrollCommandDisplayLinkScheduler: NSObject, FeedScrollCommandFrameScheduling {
    private var displayLink: CADisplayLink?
    private var pendingOperation: FeedScrollCommandFrameOperation?
    private var commandFrameGeneration = 0
    private var eligibleFrameGeneration: Int?

    func schedule(_ operation: @escaping FeedScrollCommandFrameOperation) {
        pendingOperation = operation
        guard displayLink == nil else { return }

        let displayLink = CADisplayLink(target: self, selector: #selector(displayFrameDidFire(_:)))
        self.displayLink = displayLink
        // The first callback only establishes a physical-frame boundary for work
        // enqueued from a SwiftUI measurement callback. The operation runs on a
        // later display tick, never in that originating render frame.
        eligibleFrameGeneration = commandFrameGeneration + 2
        displayLink.add(to: .main, forMode: .common)
    }

    func cancel() {
        pendingOperation = nil
        eligibleFrameGeneration = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayFrameDidFire(_ displayLink: CADisplayLink) {
        guard let pendingOperation else { return }

        commandFrameGeneration &+= 1
        guard commandFrameGeneration >= eligibleFrameGeneration ?? .max else { return }

        self.pendingOperation = nil
        eligibleFrameGeneration = nil
        displayLink.invalidate()
        self.displayLink = nil
        pendingOperation(
            FeedScrollCommandFrame(
                generation: commandFrameGeneration,
                timestamp: displayLink.timestamp
            )
        )
    }
}
