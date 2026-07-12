@testable import HackersPub
import SwiftUI
import Testing
import UIKit

struct FeedAnchorScrollViewRemountTests {
    @Test("SOC-13: remount discards cached measurements and restores only after fresh ingress")
    @MainActor
    func remountResumesPendingRestorationAfterFreshMeasurements() async throws {
        let commandFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let fixture = MountedFeedAnchorFixture(commandFrameScheduler: commandFrameScheduler)
        defer { fixture.dismantle() }
        let model = fixture.model
        let scrollView = try await fixture.waitForScrollView()
        let restoration = try await installPendingMountedRestoration(
            into: model,
            using: scrollView
        )
        let didScheduleBeforeDetach = await waitForDisplayFrames(
            until: { commandFrameScheduler.hasPendingOperation }
        )
        #expect(didScheduleBeforeDetach)
        fixture.detachAdapter()
        await awaitNextDisplayFrame()
        await awaitNextDisplayFrame()

        #expect(!commandFrameScheduler.hasPendingOperation)
        #expect(model.restoration == restoration)
        fixture.reattachAdapter()

        let restored = try await completeManualRestoration(
            commandFrameScheduler,
            model: model,
            restoration: restoration
        )

        #expect(model.observedCommandPhases.contains("materialize"))
        #expect(model.observedCommandPhases.contains("position"))
        #expect(abs((restored.primaryAnchor?.offset ?? .infinity) - restoration.offset) < 1)
    }

    @Test("SOC-13: remount does not materialize until fresh metrics follow fresh row and viewport ingress")
    @MainActor
    func remountDefersRestorationUntilFreshMetricIngress() async throws {
        let commandFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let fixture = MountedFeedAnchorFixture(commandFrameScheduler: commandFrameScheduler)
        defer { fixture.dismantle() }
        let model = fixture.model
        let scrollView = try await fixture.waitForScrollView()
        let restoration = try await installPendingMountedRestoration(
            into: model,
            using: scrollView
        )
        let didScheduleBeforeDetach = await waitForDisplayFrames(
            until: { commandFrameScheduler.hasPendingOperation }
        )
        #expect(didScheduleBeforeDetach)
        fixture.detachAdapter()
        await awaitNextDisplayFrame()
        model.permitsMeasurementMetrics = false
        fixture.reattachAdapter()
        let remountedScrollView = try await fixture.waitForScrollView()

        for _ in 0 ..< 6 {
            await awaitNextDisplayFrame()
        }
        #expect(!commandFrameScheduler.hasPendingOperation)
        #expect(model.restoration == restoration)

        model.permitsMeasurementMetrics = true
        remountedScrollView.setContentOffset(
            CGPoint(x: 0, y: remountedScrollView.contentOffset.y + 1),
            animated: false
        )
        let didScheduleAfterMetrics = await waitForDisplayFrames(
            until: { commandFrameScheduler.hasPendingOperation }
        )
        #expect(didScheduleAfterMetrics)
        let restored = try await completeManualRestoration(
            commandFrameScheduler,
            model: model,
            restoration: restoration
        )

        #expect(abs((restored.primaryAnchor?.offset ?? .infinity) - restoration.offset) < 1)
    }

    @Test("SOC-13: a remounted initial anchor survives row-first ingress and resumes after fresh metrics")
    @MainActor
    func remountRetainsInitialAnchorUntilFreshMeasurements() async throws {
        let measurementFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let commandFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let savedAnchor = FeedViewportAnchor(id: "post-2", offset: -23)
        let initialViewport = FeedViewportSnapshot(
            visibleAnchors: [savedAnchor],
            isAtTop: false
        )
        let fixture = MountedFeedAnchorFixture(
            measurementFrameScheduler: measurementFrameScheduler,
            commandFrameScheduler: commandFrameScheduler,
            initialViewport: initialViewport
        )
        defer { fixture.dismantle() }

        _ = try await fixture.waitForScrollView()
        let didScheduleBeforeDisappearance = await waitForDisplayFrames(
            until: { measurementFrameScheduler.hasPendingOperation }
        )
        #expect(didScheduleBeforeDisappearance)
        fixture.detachAdapter()
        await awaitNextDisplayFrame()
        #expect(!measurementFrameScheduler.hasPendingOperation)
        #expect(!commandFrameScheduler.hasPendingOperation)

        fixture.reattachAdapter()
        let didScheduleAfterRemount = await waitForDisplayFrames(
            until: { measurementFrameScheduler.hasPendingOperation }
        )
        #expect(didScheduleAfterRemount)
        measurementFrameScheduler.advanceFrame()
        #expect(!commandFrameScheduler.hasPendingOperation)
        measurementFrameScheduler.advanceFrame()

        try await advanceManualCommand(
            commandFrameScheduler,
            model: fixture.model,
            until: "position"
        )
        let resumed = try await advanceManualMeasurementReconciliation(
            measurementFrameScheduler,
            model: fixture.model,
            matching: { snapshot in
                guard snapshot.primaryAnchor?.id == savedAnchor.id,
                      let offset = snapshot.primaryAnchor?.offset
                else {
                    return false
                }
                return abs(offset - savedAnchor.offset) < 1
            }
        )

        #expect(fixture.model.observedCommandPhases.contains("position"))
        #expect(abs((resumed.primaryAnchor?.offset ?? .infinity) - savedAnchor.offset) < 1)
    }

    @Test("SOC-13: a preexisting restoration suppresses the stale sequence-zero initial anchor")
    @MainActor
    func initialRestorationDoesNotReplaySavedAnchorAfterAcknowledgement() async throws {
        let commandFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let savedAnchor = FeedViewportAnchor(id: "post-2", offset: -23)
        let initialViewport = FeedViewportSnapshot(
            visibleAnchors: [savedAnchor],
            isAtTop: false
        )
        let restoration = FeedScrollAnchorPolicy<String>.Restoration(
            id: "post-3",
            offset: -11,
            sequence: 7
        )
        let fixture = MountedFeedAnchorFixture(
            commandFrameScheduler: commandFrameScheduler,
            initialViewport: initialViewport,
            initialRestoration: restoration
        )
        defer { fixture.dismantle() }
        let model = fixture.model

        _ = try await fixture.waitForScrollView()
        try await advanceManualCommand(
            commandFrameScheduler,
            model: model,
            until: "materialize"
        )
        try await advanceManualCommand(
            commandFrameScheduler,
            model: model,
            until: "position"
        )
        let restoredValue = await awaitMountedViewport(
            model,
            matching: { snapshot in
                guard model.restoration == nil,
                      snapshot.primaryAnchor?.id == restoration.id,
                      let offset = snapshot.primaryAnchor?.offset
                else {
                    return false
                }
                return abs(offset - restoration.offset) < 1
            },
            trigger: {}
        )
        _ = try #require(restoredValue)
        let didObserveUnexpectedCommand = await drainUnexpectedManualCommand(commandFrameScheduler)

        #expect(!didObserveUnexpectedCommand)
        #expect(!commandFrameScheduler.hasPendingOperation)
        #expect(model.observedCommands.map(\.phase) == ["materialize", "position"])
    }
}

@MainActor
private func drainUnexpectedManualCommand(
    _ commandFrameScheduler: ManualFeedScrollCommandFrameScheduler
) async -> Bool {
    for _ in 0 ..< 8 {
        await awaitNextDisplayFrame()
        guard commandFrameScheduler.hasPendingOperation else { continue }

        commandFrameScheduler.advanceFrame()
        commandFrameScheduler.advanceFrame()
        await awaitNextDisplayFrame()
        return true
    }
    return false
}

@MainActor
private func completeManualRestoration(
    _ commandFrameScheduler: ManualFeedScrollCommandFrameScheduler,
    model: MountedFeedAnchorModel,
    restoration: FeedScrollAnchorPolicy<String>.Restoration
) async throws -> FeedViewportSnapshot<String> {
    try await advanceManualCommand(commandFrameScheduler, model: model, until: "materialize")
    try await advanceManualCommand(commandFrameScheduler, model: model, until: "position")
    let restoredValue = await awaitMountedViewport(
        model,
        matching: { snapshot in
            guard model.restoration == nil,
                  snapshot.primaryAnchor?.id == restoration.id,
                  let offset = snapshot.primaryAnchor?.offset
            else {
                return false
            }
            return abs(offset - restoration.offset) < 1
        },
        trigger: {}
    )
    return try #require(restoredValue)
}

@MainActor
private func installPendingMountedRestoration(
    into model: MountedFeedAnchorModel,
    using scrollView: UIScrollView
) async throws -> FeedScrollAnchorPolicy<String>.Restoration {
    let capturedValue = await awaitMountedViewport(
        model,
        matching: { snapshot in
            snapshot.primaryAnchor?.id == "post-2" && !snapshot.isAtTop
        },
        trigger: {
            scrollView.setContentOffset(CGPoint(x: 0, y: 95), animated: false)
        }
    )
    let captured = try #require(capturedValue)
    var policy = FeedScrollAnchorPolicy<String>()
    policy.captureBeforePrepending(
        viewport: captured,
        existingIDs: model.rows.map(\.id)
    )
    let prependedRows = prependRows(to: model.rows)
    let restorationValue = policy.takeRestoration(availableIDs: prependedRows.map(\.id))
    let restoration = try #require(restorationValue)
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
        model.rows = prependedRows
        model.restoration = restoration
    }
    return restoration
}
