@testable import HackersPub
import SwiftUI
import Testing
import UIKit

struct FeedAnchorScrollViewIntegrationTests {
    @Test("SOC-13: mounted nested rows use global-frame measurement with a nonzero content inset")
    @MainActor
    func mountedNestedRowsUseGlobalFrameOffsetWithInset() async throws {
        let fixture = MountedFeedAnchorFixture(
            usesNestedRowLayout: true,
            contentTopInset: 24
        )
        defer { fixture.dismantle() }

        let scrollView = try await fixture.waitForScrollView()
        let capturedValue = await awaitMountedViewport(
            fixture.model,
            matching: { snapshot in
                snapshot.primaryAnchor?.id == "post-2" && !snapshot.isAtTop
            },
            trigger: {
                scrollView.setContentOffset(CGPoint(x: 0, y: 95), animated: false)
            }
        )
        let captured = try #require(capturedValue)
        let diagnostics = try #require(fixture.model.latestDiagnostics)
        let capturedOffset = try #require(
            captured.visibleAnchors.first(where: { $0.id == "post-2" })?.offset
        )
        let rowGlobalFrame = try #require(diagnostics.rowGlobalFrames["post-2"])
        let viewportGlobalFrame = try #require(diagnostics.viewportGlobalFrame)
        let globalOffset = rowGlobalFrame.minY - viewportGlobalFrame.minY

        #expect((diagnostics.topInset ?? 0) > 0)
        #expect(abs(capturedOffset - globalOffset) < 1)
    }

    @Test("SOC-13: mounted capture updates visibility after a keyboard-like viewport resize")
    @MainActor
    func mountedCaptureTracksViewportResize() async throws {
        let fixture = MountedFeedAnchorFixture(usesNestedRowLayout: true)
        defer { fixture.dismantle() }

        let scrollView = try await fixture.waitForScrollView()
        let beforeResize = await awaitMountedViewport(
            fixture.model,
            matching: { snapshot in
                snapshot.visibleAnchors.contains(where: { $0.id == "post-4" })
            },
            trigger: {
                scrollView.setContentOffset(CGPoint(x: 0, y: 95), animated: false)
            }
        )
        _ = try #require(beforeResize)

        let afterResize = await awaitMountedViewport(
            fixture.model,
            matching: { snapshot in
                guard let viewportHeight = fixture.model.latestDiagnostics?.viewportHeight else {
                    return false
                }
                return abs(viewportHeight - 100) < 2
                    && !snapshot.visibleAnchors.contains(where: { $0.id == "post-4" })
            },
            trigger: {
                fixture.resizeViewport(height: 100)
            }
        )
        let resized = try #require(afterResize)
        let diagnostics = try #require(fixture.model.latestDiagnostics)
        let capturedOffset = try #require(
            resized.visibleAnchors.first(where: { $0.id == "post-2" })?.offset
        )
        let rowGlobalFrame = try #require(diagnostics.rowGlobalFrames["post-2"])
        let viewportGlobalFrame = try #require(diagnostics.viewportGlobalFrame)
        let globalOffset = rowGlobalFrame.minY - viewportGlobalFrame.minY

        #expect(abs(capturedOffset - globalOffset) < 1)
    }

    @Test("SOC-13: the mounted production adapter preserves a dynamic row within one pixel")
    @MainActor
    func mountedAdapterPreservesDynamicRowOffset() async throws {
        let result = try await runMountedAdapterRestoration()
        let materialize = try #require(
            result.observedCommands.first { $0.phase == "materialize" }
        )
        let position = try #require(
            result.observedCommands.first { $0.phase == "position" }
        )

        #expect(result.observedCommandPhases.contains("materialize"))
        #expect(result.observedCommandPhases.contains("position"))
        #expect(position.commandFrameGeneration > materialize.commandFrameGeneration)
        #expect(position.commandFrameTimestamp > materialize.commandFrameTimestamp)
        #expect(abs((result.restored.primaryAnchor?.offset ?? .infinity) - result.restoration.offset) < 1)
        #expect(abs(result.contentOffsetY - 203) < 1)
    }

    @Test("SOC-13: injected manual command frames keep materialization before exact positioning")
    @MainActor
    func manualSchedulerSeparatesMaterializationAndExactPosition() async throws {
        let commandFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let result = try await runMountedAdapterRestoration(
            commandFrameScheduler: commandFrameScheduler
        )
        let materialize = try #require(
            result.observedCommands.first { $0.phase == "materialize" }
        )
        let position = try #require(
            result.observedCommands.first { $0.phase == "position" }
        )

        #expect(materialize.commandFrameGeneration > 0)
        #expect(position.commandFrameGeneration > materialize.commandFrameGeneration)
        #expect(position.commandFrameTimestamp > materialize.commandFrameTimestamp)
    }

    @Test("SOC-13: raw measurements publish only after the current reconciliation frame")
    @MainActor
    func manualReconciliationDefersRawMeasurementPublication() async throws {
        let measurementFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let commandFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let fixture = MountedFeedAnchorFixture(
            measurementFrameScheduler: measurementFrameScheduler,
            commandFrameScheduler: commandFrameScheduler
        )
        defer { fixture.dismantle() }

        let scrollView = try await fixture.waitForScrollView()
        let didScheduleInitialMeasurement = await waitForDisplayFrames(
            until: { measurementFrameScheduler.hasPendingOperation }
        )
        #expect(didScheduleInitialMeasurement)
        #expect(fixture.model.viewport == FeedViewportSnapshot<String>())
        #expect(!commandFrameScheduler.hasPendingOperation)

        scrollView.setContentOffset(CGPoint(x: 0, y: 30), animated: false)
        await awaitNextDisplayFrame()
        scrollView.setContentOffset(CGPoint(x: 0, y: 95), animated: false)
        await awaitNextDisplayFrame()

        #expect(fixture.model.viewport == FeedViewportSnapshot<String>())
        #expect(!commandFrameScheduler.hasPendingOperation)

        let published = try await advanceManualMeasurementReconciliation(
            measurementFrameScheduler,
            model: fixture.model,
            matching: { snapshot in
                snapshot.primaryAnchor?.id == "post-2"
                    && abs((snapshot.primaryAnchor?.offset ?? 0) + 23) < 1
            }
        )
        #expect(published.primaryAnchor?.id == "post-2")
        #expect(!commandFrameScheduler.hasPendingOperation)
    }

    @Test("SOC-13: disappearance cancels both manual scheduler queues")
    @MainActor
    func disappearanceCancelsBothManualSchedulerQueues() async throws {
        let measurementFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let commandFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let initialViewport = FeedViewportSnapshot(
            visibleAnchors: [FeedViewportAnchor(id: "post-2", offset: -23)],
            isAtTop: false
        )
        let fixture = MountedFeedAnchorFixture(
            measurementFrameScheduler: measurementFrameScheduler,
            commandFrameScheduler: commandFrameScheduler,
            initialViewport: initialViewport
        )

        let scrollView = try await fixture.waitForScrollView()
        _ = try await advanceManualMeasurementReconciliation(
            measurementFrameScheduler,
            model: fixture.model,
            matching: { _ in commandFrameScheduler.hasPendingOperation }
        )
        #expect(commandFrameScheduler.hasPendingOperation)
        scrollView.setContentOffset(CGPoint(x: 0, y: 30), animated: false)
        let didScheduleMeasurement = await waitForDisplayFrames(
            until: { measurementFrameScheduler.hasPendingOperation }
        )
        #expect(didScheduleMeasurement)
        #expect(commandFrameScheduler.hasPendingOperation)
        fixture.dismantle()
        await awaitNextDisplayFrame()

        #expect(!measurementFrameScheduler.hasPendingOperation)
        #expect(!commandFrameScheduler.hasPendingOperation)
    }

    @Test("SOC-13: mounted bottom capture restores and settles at the adjusted bottom-inset range")
    @MainActor
    func mountedBottomInsetRestorationUsesAdjustedBottomRange() async throws {
        let initialViewport = FeedViewportSnapshot(
            visibleAnchors: [FeedViewportAnchor(id: "post-5", offset: 65)],
            isAtTop: false
        )
        let result = try await runMountedAdapterRestoration(
            contentTopInset: 24,
            contentBottomInset: 34,
            initialViewport: initialViewport,
            requiresPositionCommand: false
        )
        let capturedTopInset = try #require(result.capturedTopInset)
        let capturedBottomInset = try #require(result.capturedBottomInset)
        let capturedContentHeight = try #require(result.capturedContentHeight)
        let capturedViewportHeight = try #require(result.capturedViewportHeight)
        let finalTopInset = try #require(result.topInset)
        let finalBottomInset = try #require(result.bottomInset)
        let finalContentHeight = try #require(result.contentHeight)
        let finalViewportHeight = try #require(result.viewportHeight)
        let capturedMaximumY = max(
            0,
            capturedContentHeight - capturedViewportHeight + capturedTopInset + capturedBottomInset
        ) - capturedTopInset
        let finalMaximumY = max(
            0,
            finalContentHeight - finalViewportHeight + finalTopInset + finalBottomInset
        ) - finalTopInset

        #expect(capturedBottomInset > 0)
        #expect(finalBottomInset > 0)
        #expect(abs(result.capturedContentOffsetY - capturedMaximumY) < 1)
        #expect(abs(result.contentOffsetY - finalMaximumY) < 1)
        #expect(result.bindingAcknowledged)
        #expect(abs((result.restored.primaryAnchor?.offset ?? .infinity) - result.restoration.offset) < 1)
    }
}

extension FeedAnchorScrollViewIntegrationTests {
    @Test("SOC-13: an identical CGRect emits a current semantic measurement without commands")
    @MainActor
    func identicalFrameSemanticMeasurementAcknowledgesWithoutMaterialization() async throws {
        let commandFrameScheduler = ManualFeedScrollCommandFrameScheduler()
        let fixture = MountedFeedAnchorFixture(commandFrameScheduler: commandFrameScheduler)
        defer { fixture.dismantle() }
        let model = fixture.model
        _ = try await fixture.waitForScrollView()

        let restoration = try await makeExactMountedTargetRestoration(model: model)
        #expect(!commandFrameScheduler.hasPendingOperation)
        let baseline = try ExactMountedTargetCommandBaseline(
            model: model,
            commandFrameScheduler: commandFrameScheduler
        )

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { model.restoration = restoration }
        let acknowledged = await awaitMountedViewport(
            model,
            matching: { _ in model.restoration == nil },
            trigger: {}
        )

        _ = try #require(
            acknowledged,
            acknowledgementTimeoutComment(model: model, commandFrameScheduler: commandFrameScheduler)
        )
        try assertExactTargetAcknowledgement(
            model: model,
            commandFrameScheduler: commandFrameScheduler,
            baseline: baseline
        )
    }
}

@MainActor
private struct ExactMountedTargetCommandBaseline {
    let scheduleCount: Int
    let observedCommandPhases: Set<String>
    let observedCommands: [ObservedFeedScrollCommand]
    let latestCommandPhase: String?
    let issuedTargetY: CGFloat?
    let latestCommandFrameGeneration: Int?
    let latestCommandFrameTimestamp: TimeInterval?

    init(
        model: MountedFeedAnchorModel,
        commandFrameScheduler: ManualFeedScrollCommandFrameScheduler
    ) throws {
        let diagnostics = try #require(model.latestDiagnostics)
        scheduleCount = commandFrameScheduler.scheduleCount
        observedCommandPhases = model.observedCommandPhases
        observedCommands = model.observedCommands
        latestCommandPhase = diagnostics.latestCommandPhase
        issuedTargetY = diagnostics.issuedTargetY
        latestCommandFrameGeneration = diagnostics.latestCommandFrameGeneration
        latestCommandFrameTimestamp = diagnostics.latestCommandFrameTimestamp
    }
}

@MainActor
private func assertExactTargetAcknowledgement(
    model: MountedFeedAnchorModel,
    commandFrameScheduler: ManualFeedScrollCommandFrameScheduler,
    baseline: ExactMountedTargetCommandBaseline
) throws {
    let acknowledgedDiagnostics = try #require(model.latestDiagnostics)
    let diagnostics = acknowledgedDiagnostics.description
    #expect(model.restoration == nil, "exact target was not acknowledged: \(diagnostics)")
    #expect(acknowledgedDiagnostics.bindingAcknowledged, "exact target binding remains bound: \(diagnostics)")
    #expect(acknowledgedDiagnostics.pendingSequence == nil, "exact target remains pending: \(diagnostics)")
    #expect(acknowledgedDiagnostics.attemptCount == 0, "exact target recorded an attempt: \(diagnostics)")
    #expect(commandFrameScheduler.scheduleCount == baseline.scheduleCount, "\(diagnostics)")
    #expect(model.observedCommandPhases == baseline.observedCommandPhases, "\(diagnostics)")
    #expect(model.observedCommands == baseline.observedCommands, "\(diagnostics)")
    #expect(acknowledgedDiagnostics.latestCommandPhase == baseline.latestCommandPhase, "\(diagnostics)")
    #expect(acknowledgedDiagnostics.issuedTargetY == baseline.issuedTargetY, "\(diagnostics)")
    #expect(
        acknowledgedDiagnostics.latestCommandFrameGeneration == baseline.latestCommandFrameGeneration,
        "\(diagnostics)"
    )
    #expect(
        acknowledgedDiagnostics.latestCommandFrameTimestamp == baseline.latestCommandFrameTimestamp,
        "\(diagnostics)"
    )
    #expect(!commandFrameScheduler.hasPendingOperation, "exact target left work pending: \(diagnostics)")
}

@MainActor
private func acknowledgementTimeoutComment(
    model: MountedFeedAnchorModel,
    commandFrameScheduler: ManualFeedScrollCommandFrameScheduler
) -> Comment {
    Comment(
        rawValue: "exact target acknowledgement did not settle: "
            + "diagnostics=\(model.latestDiagnostics?.description ?? "none") "
            + "restoration=\(String(describing: model.restoration)) "
            + "scheduleCount=\(commandFrameScheduler.scheduleCount) "
            + "pending=\(commandFrameScheduler.hasPendingOperation) "
            + "observedPhases=\(model.observedCommandPhases)"
    )
}

@MainActor
private func exactTargetCaptureTimeoutComment(
    model: MountedFeedAnchorModel
) -> Comment {
    Comment(
        rawValue: "exact target capture did not settle: "
            + "viewport=\(model.viewport) "
            + "diagnostics=\(model.latestDiagnostics?.description ?? "none")"
    )
}

@MainActor
private func makeExactMountedTargetRestoration(
    model: MountedFeedAnchorModel
) async throws -> FeedScrollAnchorPolicy<String>.Restoration {
    let capturedValue = await awaitMountedViewport(
        model,
        matching: { snapshot in
            guard let primaryAnchor = snapshot.primaryAnchor else {
                return false
            }
            return primaryAnchor.id == "post-1"
                && abs(primaryAnchor.offset) < 1
                && snapshot.isAtTop
        },
        trigger: {}
    )
    let captured = try #require(capturedValue, exactTargetCaptureTimeoutComment(model: model))
    let capturedAnchor = try #require(captured.primaryAnchor)
    await awaitNextDisplayFrame()
    let exactDiagnostics = try #require(model.latestDiagnostics)
    let exactAnchor = try #require(
        exactDiagnostics.rowOffsets.first { $0.id == capturedAnchor.id }
    )
    let exactFrame = try #require(exactDiagnostics.rowGlobalFrames[exactAnchor.id])
    #expect(abs(capturedAnchor.offset - exactAnchor.offset) < 0.5)
    #expect(!exactFrame.isEmpty)
    #expect(exactDiagnostics.hasCurrentLayoutRowIngress)
    #expect(exactDiagnostics.rowFrameRevision == exactDiagnostics.layoutRevision)
    return FeedScrollAnchorPolicy<String>.Restoration(
        id: exactAnchor.id,
        offset: exactAnchor.offset,
        sequence: 1
    )
}
