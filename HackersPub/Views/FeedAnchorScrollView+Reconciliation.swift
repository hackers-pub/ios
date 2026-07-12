import SwiftUI

extension FeedAnchorScrollView {
    func applyPendingAdjustmentIfReady() {
        let measurement = measurementBuffer
        if let pendingRestoration {
            guard measurement.isReadyForPendingRestoration,
                  measurement.rowFrameRevision == pendingRestoration.sequence
            else {
                return
            }

            if let frame = measurement.rowFrames[pendingRestoration.id], !measurement.viewportFrame.isEmpty {
                let currentAnchorOffset = frame.minY - measurement.viewportFrame.minY
                if abs(currentAnchorOffset - pendingRestoration.offset) < 0.5 {
                    acknowledge(pendingRestoration)
                    return
                }
            }

            if pendingMaterializationSequence == pendingRestoration.sequence {
                scheduleMaterialization(for: pendingRestoration)
                return
            }

            guard let frame = measurement.rowFrames[pendingRestoration.id] else {
                scheduleMaterialization(for: pendingRestoration)
                return
            }

            guard !measurement.viewportFrame.isEmpty else {
                return
            }

            guard attemptTracker.mayIssue,
                  measurement.metricFence.allowsCommand,
                  pendingCommand == nil,
                  let command = positionCommand(for: pendingRestoration, frame: frame)
            else {
                if canRequireVisibleRetry(for: measurement) {
                    attemptTracker.requireVisibleRetry()
                }
                return
            }
            schedule(command)
            return
        }

        guard let initialAnchor,
              measurement.isReadyForPendingRestoration,
              measurement.rowFrameRevision == 0,
              let frame = measurement.rowFrames[initialAnchor.id]
        else {
            return
        }
        scheduleInitialAnchor(initialAnchor, frame: frame)
    }

    func canRequireVisibleRetry(for measurement: FeedScrollMeasurementBuffer<ID>) -> Bool {
        measurement.scrollMetrics != nil
            && measurement.metricFence.allowsCommand
            && pendingCommand == nil
    }

    func acknowledge(_ restoration: FeedScrollAnchorPolicy<ID>.Restoration) {
        guard measurementBuffer.isReadyForPendingRestoration else { return }
        pendingRestoration = nil
        pendingMaterializationSequence = nil
        attemptTracker.reset()
        measurementBuffer.prepareForLayoutRevision(0)
        measurementBuffer.resetMetricFence()
        cancelScheduledWork()
        cancelWatchdog()
        if self.restoration?.sequence == restoration.sequence {
            self.restoration = nil
        }
        reportDiagnostics()
    }

    func positionCommand(
        for restoration: FeedScrollAnchorPolicy<ID>.Restoration,
        frame: CGRect
    ) -> FeedScrollCommand<ID>? {
        let measurement = measurementBuffer
        guard let scrollMetrics = measurement.scrollMetrics,
              !measurement.viewportFrame.isEmpty
        else {
            return nil
        }
        let currentAnchorOffset = frame.minY - measurement.viewportFrame.minY
        let targetY = FeedScrollOffsetAdjustment.targetScrollPositionY(
            metrics: scrollMetrics,
            currentAnchorOffset: currentAnchorOffset,
            desiredAnchorOffset: restoration.offset
        )
        let currentLogicalY = scrollMetrics.contentOffsetY + scrollMetrics.topInset
        guard abs(targetY - currentLogicalY) >= 0.5 else { return nil }

        return FeedScrollCommand(
            sequence: restoration.sequence,
            attempt: attemptTracker.attemptCount + 1,
            phase: .position(targetY)
        )
    }

    func scheduleMaterialization(for restoration: FeedScrollAnchorPolicy<ID>.Restoration) {
        guard measurementBuffer.isReadyForPendingRestoration,
              attemptTracker.mayIssue,
              measurementBuffer.metricFence.allowsCommand,
              pendingCommand == nil
        else {
            return
        }
        schedule(
            FeedScrollCommand(
                sequence: restoration.sequence,
                attempt: attemptTracker.attemptCount + 1,
                phase: .materialize(restoration.id)
            )
        )
    }

    func scheduleInitialAnchor(_ anchor: FeedViewportAnchor<ID>, frame: CGRect) {
        guard pendingCommand == nil else { return }
        let restoration = FeedScrollAnchorPolicy<ID>.Restoration(
            id: anchor.id,
            offset: anchor.offset,
            sequence: 0
        )
        guard let command = positionCommand(for: restoration, frame: frame) else {
            initialAnchor = nil
            return
        }
        schedule(command)
    }
}

extension FeedAnchorScrollView {
    func execute(
        _ token: FeedScrollCommandExecutionToken<ID>,
        commandFrame: FeedScrollCommandFrame
    ) {
        guard pendingCommand == token else { return }

        let command = token.command
        let measurement = measurementBuffer
        guard FeedScrollCommandFreshness.isCurrent(
            token,
            context: currentFreshnessContext()
        ) else {
            pendingCommand = nil
            scheduleMeasurementReconciliation()
            return
        }

        var updatedPosition = scrollPosition
        switch command.phase {
        case let .materialize(id):
            pendingMaterializationSequence = nil
            latestCommandPhase = "materialize"
            latestCommandFrameGeneration = commandFrame.generation
            latestCommandFrameTimestamp = commandFrame.timestamp
            latestIssuedTargetY = nil
            updatedPosition.scrollTo(id: id, anchor: .top)
        case let .position(targetY):
            latestCommandPhase = "position"
            latestCommandFrameGeneration = commandFrame.generation
            latestCommandFrameTimestamp = commandFrame.timestamp
            latestIssuedTargetY = targetY
            updatedPosition.scrollTo(y: targetY)
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollPosition = updatedPosition
        }
        if command.sequence != 0 {
            attemptTracker.recordIssuedCommand()
            measurement.metricFence.recordIssuedCommand()
            armWatchdog(for: command)
        } else {
            initialAnchor = nil
        }
        pendingCommand = nil
        reportDiagnostics()
    }

    func armWatchdog(for command: FeedScrollCommand<ID>) {
        guard let awaitingMetricGeneration = measurementBuffer.metricFence.awaitingGeneration else { return }
        cancelWatchdog()
        let token = FeedScrollCommandToken(
            sequence: command.sequence,
            attempt: command.attempt,
            awaitingMetricGeneration: awaitingMetricGeneration
        )
        watchdogToken = token
        watchdogTask = Task { @MainActor in
            try? await Task.sleep(for: watchdogTimeout)
            guard !Task.isCancelled,
                  FeedScrollWatchdog.shouldRequireRetry(
                      token: token,
                      pendingSequence: pendingRestoration?.sequence,
                      attemptCount: attemptTracker.attemptCount,
                      awaitingMetricGeneration: measurementBuffer.metricFence.awaitingGeneration,
                      scrollMetricGeneration: measurementBuffer.metricFence.generation
                  )
            else {
                return
            }
            attemptTracker.requireVisibleRetry()
            watchdogToken = nil
            watchdogTask = nil
            cancelScheduledWork()
            reportDiagnostics()
        }
    }

    func cancelWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
        watchdogToken = nil
    }

    func schedule(_ command: FeedScrollCommand<ID>) {
        cancelScheduledCommand()
        let token = FeedScrollCommandExecutionToken(
            command: command,
            context: currentFreshnessContext()
        )
        pendingCommand = token
        commandFrameScheduler.schedule { commandFrame in
            execute(token, commandFrame: commandFrame)
        }
    }

    func cancelScheduledCommand() {
        commandFrameScheduler.cancel()
        pendingCommand = nil
    }

    func scheduleMeasurementReconciliation() {
        let measurement = measurementBuffer
        let token = FeedScrollMeasurementToken(context: currentFreshnessContext())
        guard measurement.pendingToken != token else { return }

        measurement.pendingToken = token
        measurementFrameScheduler.schedule { _ in
            reconcileMeasurement(token)
        }
    }

    func reconcileMeasurement(_ token: FeedScrollMeasurementToken) {
        let measurement = measurementBuffer
        guard measurement.pendingToken == token else { return }

        guard FeedScrollMeasurementFreshness.isCurrent(
            token,
            context: currentFreshnessContext()
        ) else {
            measurement.pendingToken = nil
            scheduleMeasurementReconciliation()
            return
        }

        measurement.pendingToken = nil
        if measurement.consumeWatchdogCancellation() {
            cancelWatchdog()
        }
        updateViewportSnapshot()
        applyPendingAdjustmentIfReady()
        reportDiagnostics()
    }

    func cancelMeasurementReconciliation() {
        measurementFrameScheduler.cancel()
        measurementBuffer.pendingToken = nil
    }

    func cancelScheduledWork() {
        cancelScheduledCommand()
        cancelMeasurementReconciliation()
    }

    var layoutRevision: Int {
        FeedScrollAnchorLayoutRevision.value(for: restoration)
    }

    func currentFreshnessContext() -> FeedScrollFreshnessContext {
        FeedScrollFreshnessContext(
            restorationSequence: restoration?.sequence,
            pendingRestorationSequence: pendingRestoration?.sequence,
            layoutRevision: layoutRevision,
            frameVersion: measurementBuffer.frameVersion,
            scrollMetricGeneration: measurementBuffer.metricFence.generation
        )
    }

    func reportDiagnostics() {
        guard let onDiagnostic else { return }
        let measurement = measurementBuffer
        let rowOffsets = measurement.rowFrames.map { id, frame in
            FeedViewportAnchor(id: id, offset: frame.minY - measurement.viewportFrame.minY)
        }
        .sorted { $0.offset < $1.offset }
        onDiagnostic(
            FeedAnchorScrollDiagnostics(
                pendingSequence: pendingRestoration?.sequence,
                pendingID: pendingRestoration?.id,
                pendingOffset: pendingRestoration?.offset,
                attemptCount: attemptTracker.attemptCount,
                issuedTargetY: latestIssuedTargetY,
                latestCommandPhase: latestCommandPhase,
                latestCommandFrameGeneration: latestCommandFrameGeneration,
                latestCommandFrameTimestamp: latestCommandFrameTimestamp,
                frameVersion: measurement.frameVersion,
                layoutRevision: layoutRevision,
                rowFrameRevision: measurement.rowFrameRevision,
                measurementEpoch: measurement.measurementEpoch,
                hasCurrentLayoutRowIngress: measurement.hasCurrentLayoutRowIngress,
                isReadyForPendingRestoration: measurement.isReadyForPendingRestoration,
                scrollMetricGeneration: measurement.metricFence.generation,
                awaitingMetricGeneration: measurement.metricFence.awaitingGeneration,
                rowOffsets: rowOffsets,
                rowGlobalFrames: measurement.rowFrames,
                viewportGlobalFrame: measurement.viewportFrame.isEmpty ? nil : measurement.viewportFrame,
                bindingAcknowledged: restoration == nil,
                contentOffsetY: measurement.scrollMetrics?.contentOffsetY,
                topInset: measurement.scrollMetrics?.topInset,
                bottomInset: measurement.scrollMetrics?.bottomInset,
                contentHeight: measurement.scrollMetrics?.contentHeight,
                viewportHeight: measurement.scrollMetrics?.viewportHeight
            )
        )
    }
}
