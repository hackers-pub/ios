@testable import HackersPub
import SwiftUI
import Testing
import UIKit

@MainActor
func runMountedAdapterRestoration(
    commandFrameScheduler: ManualFeedScrollCommandFrameScheduler? = nil,
    contentTopInset: CGFloat = 0,
    contentBottomInset: CGFloat = 0,
    captureOffsetY: CGFloat = 95,
    initialViewport: FeedViewportSnapshot<String>? = nil,
    requiresPositionCommand: Bool = true
) async throws -> MountedFeedAnchorRestorationResult {
    let fixture = MountedFeedAnchorFixture(
        commandFrameScheduler: commandFrameScheduler,
        contentTopInset: contentTopInset,
        contentBottomInset: contentBottomInset,
        initialViewport: initialViewport ?? .init()
    )
    defer { fixture.dismantle() }
    let model = fixture.model
    let scrollView = try await fixture.waitForScrollView()
    let captured = try await captureMountedViewport(
        model: model,
        scrollView: scrollView,
        targetOffsetY: captureOffsetY,
        expectedInsets: (top: contentTopInset, bottom: contentBottomInset),
        initialViewport: initialViewport
    )
    let capturedDiagnostics = try #require(model.latestDiagnostics)
    let capturedContentOffsetY = scrollView.contentOffset.y
    let restoration = try makeMountedRestoration(from: captured, model: model)
    let prependedRows = prependRows(to: model.rows)
    let restored = try await applyMountedRestoration(
        restoration,
        prependedRows: prependedRows,
        model: model,
        commandFrameScheduler: commandFrameScheduler,
        requiresPositionCommand: requiresPositionCommand
    )
    let diagnostics = try #require(model.latestDiagnostics)

    return MountedFeedAnchorRestorationResult(
        restoration: restoration,
        restored: restored,
        contentOffsetY: scrollView.contentOffset.y,
        observedCommandPhases: model.observedCommandPhases,
        observedCommands: model.observedCommands,
        issuedTargetY: diagnostics.issuedTargetY,
        topInset: diagnostics.topInset,
        bottomInset: diagnostics.bottomInset,
        contentHeight: diagnostics.contentHeight,
        viewportHeight: diagnostics.viewportHeight,
        bindingAcknowledged: diagnostics.bindingAcknowledged,
        capturedContentOffsetY: capturedContentOffsetY,
        capturedTopInset: capturedDiagnostics.topInset,
        capturedBottomInset: capturedDiagnostics.bottomInset,
        capturedContentHeight: capturedDiagnostics.contentHeight,
        capturedViewportHeight: capturedDiagnostics.viewportHeight
    )
}

@MainActor
private func captureMountedViewport(
    model: MountedFeedAnchorModel,
    scrollView: UIScrollView,
    targetOffsetY: CGFloat,
    expectedInsets: (top: CGFloat, bottom: CGFloat),
    initialViewport: FeedViewportSnapshot<String>?
) async throws -> FeedViewportSnapshot<String> {
    let didSettle = await waitForDisplayFrames(
        until: {
            mountedCaptureHasSettled(
                model: model,
                scrollView: scrollView,
                expectedTopInset: expectedInsets.top,
                expectedBottomInset: expectedInsets.bottom
            )
        }
    )
    #expect(
        didSettle,
        mountedCaptureDiagnosticComment(
            model: model,
            scrollView: scrollView,
            targetOffsetY: targetOffsetY,
            expectedTopInset: expectedInsets.top,
            expectedBottomInset: expectedInsets.bottom
        )
    )
    let capturedValue = await awaitMountedCapture(
        model: model,
        scrollView: scrollView,
        targetOffsetY: targetOffsetY,
        initialViewport: initialViewport
    )
    return try #require(
        capturedValue,
        mountedCaptureDiagnosticComment(
            model: model,
            scrollView: scrollView,
            targetOffsetY: targetOffsetY,
            expectedTopInset: expectedInsets.top,
            expectedBottomInset: expectedInsets.bottom
        )
    )
}

@MainActor
private func awaitMountedCapture(
    model: MountedFeedAnchorModel,
    scrollView: UIScrollView,
    targetOffsetY: CGFloat,
    initialViewport: FeedViewportSnapshot<String>?
) async -> FeedViewportSnapshot<String>? {
    await awaitMountedViewport(
        model,
        matching: { snapshot in
            guard let diagnostics = model.latestDiagnostics,
                  let viewportHeight = diagnostics.viewportHeight,
                  let contentHeight = diagnostics.contentHeight,
                  abs(viewportHeight - 180) < 2,
                  contentHeight > viewportHeight
            else {
                return false
            }
            if let initialViewport {
                guard !snapshot.isAtTop,
                      snapshot.primaryAnchor != nil,
                      let initialAnchor = initialViewport.primaryAnchor,
                      snapshot.visibleAnchors.contains(where: {
                          $0.id == initialAnchor.id && abs($0.offset - initialAnchor.offset) < 1
                      })
                else {
                    return false
                }
                let adjustedInsets = scrollView.adjustedContentInset
                let maximumY = max(
                    -adjustedInsets.top,
                    scrollView.contentSize.height - scrollView.bounds.height + adjustedInsets.bottom
                )
                return abs(scrollView.contentOffset.y - maximumY) < 1
            }
            return snapshot.primaryAnchor != nil && !snapshot.isAtTop
        },
        trigger: {
            guard initialViewport == nil else { return }
            let minimumY = -scrollView.adjustedContentInset.top
            let maximumY = max(
                minimumY,
                scrollView.contentSize.height
                    - scrollView.bounds.height
                    + scrollView.adjustedContentInset.bottom
            )
            let physicalTargetY = min(max(targetOffsetY, minimumY), maximumY)
            scrollView.setContentOffset(CGPoint(x: 0, y: physicalTargetY), animated: false)
        }
    )
}

@MainActor
private func mountedCaptureDiagnosticComment(
    model: MountedFeedAnchorModel,
    scrollView: UIScrollView,
    targetOffsetY: CGFloat,
    expectedTopInset: CGFloat,
    expectedBottomInset: CGFloat
) -> Comment {
    Comment(
        rawValue: mountedCaptureTimeoutDiagnostic(
            model: model,
            scrollView: scrollView,
            targetOffsetY: targetOffsetY,
            expectedTopInset: expectedTopInset,
            expectedBottomInset: expectedBottomInset
        )
    )
}

@MainActor
private func mountedCaptureHasSettled(
    model: MountedFeedAnchorModel,
    scrollView: UIScrollView,
    expectedTopInset: CGFloat,
    expectedBottomInset: CGFloat
) -> Bool {
    guard let diagnostics = model.latestDiagnostics,
          let contentHeight = diagnostics.contentHeight,
          let viewportHeight = diagnostics.viewportHeight,
          let topInset = diagnostics.topInset,
          let bottomInset = diagnostics.bottomInset,
          let viewportFrame = diagnostics.viewportGlobalFrame,
          !viewportFrame.isEmpty,
          !diagnostics.rowGlobalFrames.isEmpty,
          diagnostics.rowFrameRevision == diagnostics.layoutRevision,
          diagnostics.hasCurrentLayoutRowIngress,
          diagnostics.isReadyForPendingRestoration
    else {
        return false
    }
    let adjustedInsets = scrollView.adjustedContentInset
    return contentHeight > viewportHeight
        && scrollView.bounds.height > 0
        && abs(adjustedInsets.top - expectedTopInset) < 0.5
        && abs(adjustedInsets.bottom - expectedBottomInset) < 0.5
        && abs(topInset - adjustedInsets.top) < 0.5
        && abs(bottomInset - adjustedInsets.bottom) < 0.5
}

@MainActor
private func mountedCaptureTimeoutDiagnostic(
    model: MountedFeedAnchorModel,
    scrollView: UIScrollView,
    targetOffsetY: CGFloat,
    expectedTopInset: CGFloat,
    expectedBottomInset: CGFloat
) -> String {
    let adjustedInsets = scrollView.adjustedContentInset
    let minimumY = -adjustedInsets.top
    let maximumY = max(
        minimumY,
        scrollView.contentSize.height - scrollView.bounds.height + adjustedInsets.bottom
    )
    let physicalTargetY = min(max(targetOffsetY, minimumY), maximumY)
    let diagnostics = model.latestDiagnostics
    return "mounted capture did not settle: contentOffset=\(scrollView.contentOffset) "
        + "contentSize=\(scrollView.contentSize) bounds=\(scrollView.bounds) "
        + "adjustedInsets=\(adjustedInsets) expectedInsets=(\(expectedTopInset), \(expectedBottomInset)) "
        + "minimumY=\(minimumY) maximumY=\(maximumY) targetY=\(physicalTargetY) "
        + "rowFrames=\(String(describing: diagnostics?.rowGlobalFrames)) "
        + "viewport=\(String(describing: diagnostics?.viewportGlobalFrame)) "
        + "layoutRevision=\(String(describing: diagnostics?.layoutRevision)) "
        + "rowFrameRevision=\(String(describing: diagnostics?.rowFrameRevision)) "
        + "measurementEpoch=\(String(describing: diagnostics?.measurementEpoch)) "
        + "rowIngress=\(String(describing: diagnostics?.hasCurrentLayoutRowIngress)) "
        + "ready=\(String(describing: diagnostics?.isReadyForPendingRestoration))"
}

@MainActor
private func makeMountedRestoration(
    from captured: FeedViewportSnapshot<String>,
    model: MountedFeedAnchorModel
) throws -> FeedScrollAnchorPolicy<String>.Restoration {
    var policy = FeedScrollAnchorPolicy<String>()
    policy.captureBeforePrepending(
        viewport: captured,
        existingIDs: model.rows.map(\.id)
    )
    let restorationValue = policy.takeRestoration(availableIDs: prependRows(to: model.rows).map(\.id))
    return try #require(restorationValue)
}

@MainActor
func prependRows(
    to rows: [MountedFeedAnchorModel.Row]
) -> [MountedFeedAnchorModel.Row] {
    var prependedRows = [MountedFeedAnchorModel.Row]()
    prependedRows.append(.init(id: "post-new-1", height: 41))
    prependedRows.append(.init(id: "post-new-2", height: 67))
    prependedRows.append(contentsOf: rows)
    return prependedRows
}

@MainActor
private func applyMountedRestoration(
    _ restoration: FeedScrollAnchorPolicy<String>.Restoration,
    prependedRows: [MountedFeedAnchorModel.Row],
    model: MountedFeedAnchorModel,
    commandFrameScheduler: ManualFeedScrollCommandFrameScheduler?,
    requiresPositionCommand: Bool
) async throws -> FeedViewportSnapshot<String> {
    let matchesRestoration = matchesMountedRestoration(
        restoration,
        model: model,
        requiresPositionCommand: requiresPositionCommand
    )
    let applyRestoration = {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            model.rows = prependedRows
            model.restoration = restoration
        }
    }

    let restoredValue: FeedViewportSnapshot<String>?
    if let commandFrameScheduler {
        await awaitNextDisplayFrame()
        applyRestoration()
        try await advanceManualCommand(
            commandFrameScheduler,
            model: model,
            until: "materialize"
        )
        if requiresPositionCommand {
            try await advanceManualCommand(
                commandFrameScheduler,
                model: model,
                until: "position"
            )
        }
        restoredValue = await awaitMountedViewport(
            model,
            matching: matchesRestoration,
            trigger: {}
        )
    } else {
        restoredValue = await awaitMountedViewport(
            model,
            matching: matchesRestoration,
            trigger: applyRestoration
        )
    }
    let diagnosticMessage = "\(model.latestDiagnostics?.description ?? "none") phases=\(model.observedCommandPhases)"
    #expect(restoredValue != nil, "adapter diagnostics: \(diagnosticMessage)")
    return try #require(restoredValue)
}

@MainActor
private func matchesMountedRestoration(
    _ restoration: FeedScrollAnchorPolicy<String>.Restoration,
    model: MountedFeedAnchorModel,
    requiresPositionCommand: Bool
) -> @MainActor (FeedViewportSnapshot<String>) -> Bool {
    { snapshot in
        guard model.restoration == nil,
              model.observedCommandPhases.contains("materialize"),
              snapshot.primaryAnchor?.id == restoration.id,
              let offset = snapshot.primaryAnchor?.offset
        else {
            return false
        }
        if requiresPositionCommand, !model.observedCommandPhases.contains("position") {
            return false
        }
        return abs(offset - restoration.offset) < 1
    }
}

@MainActor
func awaitMountedViewport(
    _ model: MountedFeedAnchorModel,
    matching predicate: @escaping @MainActor (FeedViewportSnapshot<String>) -> Bool,
    trigger: () -> Void
) async -> FeedViewportSnapshot<String>? {
    await awaitNextDisplayFrame()
    trigger()
    for _ in 0 ..< 120 {
        await awaitNextDisplayFrame()
        let snapshot = model.viewport
        if predicate(snapshot) {
            return snapshot
        }
    }
    return nil
}

@MainActor
func advanceManualCommand(
    _ commandFrameScheduler: ManualFeedScrollCommandFrameScheduler,
    model: MountedFeedAnchorModel,
    until phase: String
) async throws {
    for _ in 0 ..< 8 {
        guard await waitForDisplayFrames(until: { commandFrameScheduler.hasPendingOperation }) else {
            break
        }
        await awaitNextDisplayFrame()
        commandFrameScheduler.advanceFrame()
        await awaitNextDisplayFrame()
        if model.observedCommandPhases.contains(phase) {
            return
        }
    }
    throw MountedFeedAnchorFixtureError.manualCommandNotObserved(phase)
}

@MainActor
func advanceManualMeasurementReconciliation(
    _ measurementFrameScheduler: ManualFeedScrollCommandFrameScheduler,
    model: MountedFeedAnchorModel,
    matching predicate: @escaping (FeedViewportSnapshot<String>) -> Bool
) async throws -> FeedViewportSnapshot<String> {
    for _ in 0 ..< 8 {
        guard await waitForDisplayFrames(until: { measurementFrameScheduler.hasPendingOperation }) else {
            break
        }
        measurementFrameScheduler.advanceFrame()
        await awaitNextDisplayFrame()
        measurementFrameScheduler.advanceFrame()
        await awaitNextDisplayFrame()
        if predicate(model.viewport) {
            return model.viewport
        }
    }
    throw MountedFeedAnchorFixtureError.manualMeasurementNotPublished
}
