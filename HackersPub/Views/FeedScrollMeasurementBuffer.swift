import SwiftUI

struct FeedAnchorRowGeometry: Equatable {
    let frame: CGRect
    let layoutRevision: Int
    let measurementEpoch: Int
    let appearanceGeneration: Int
}

struct FeedAnchorViewportGeometry: Equatable {
    let frame: CGRect
    let measurementEpoch: Int
}

struct FeedAnchorRowMeasurementStamp: Hashable {
    let layoutRevision: Int
    let measurementEpoch: Int
    let appearanceGeneration: Int
}

private struct FeedScrollRowOwnerMeasurements {
    var frames: [UUID: CGRect] = [:]
    var orders: [UUID: Int] = [:]
    var activeGenerations: [UUID: Int] = [:]
    var retiredGenerations: [UUID: Int] = [:]

    var currentOwner: UUID? {
        orders.max { $0.value < $1.value }?.key
    }

    var isEmpty: Bool {
        frames.isEmpty && retiredGenerations.isEmpty
    }

    mutating func beginAppearance(
        owner: UUID,
        generation: Int,
        nextOrder: inout Int
    ) -> Bool? {
        guard generation > retiredGenerations[owner, default: -1] else {
            return nil
        }

        let activeGeneration = activeGenerations[owner]
        guard activeGeneration == nil || generation >= activeGeneration! else {
            return nil
        }
        let startsNewLifetime = activeGeneration == nil || generation > activeGeneration!
        if let activeGeneration, startsNewLifetime {
            retiredGenerations[owner] = max(retiredGenerations[owner, default: -1], activeGeneration)
            frames.removeValue(forKey: owner)
            orders.removeValue(forKey: owner)
            activeGenerations.removeValue(forKey: owner)
        }

        if frames[owner] == nil {
            nextOrder &+= 1
            orders[owner] = nextOrder
        }
        return startsNewLifetime
    }

    mutating func remove(owner: UUID, generation: Int) -> Bool {
        guard activeGenerations[owner] == generation,
              frames.removeValue(forKey: owner) != nil
        else {
            return false
        }

        orders.removeValue(forKey: owner)
        activeGenerations.removeValue(forKey: owner)
        retiredGenerations[owner] = max(retiredGenerations[owner, default: -1], generation)
        return true
    }
}

@MainActor
final class FeedScrollMeasurementBuffer<ID: Hashable> {
    var viewportFrame = CGRect.zero
    var rowFrames: [ID: CGRect] = [:]
    private var rowOwners: [ID: UUID] = [:]
    private var rowOwnerMeasurements: [ID: FeedScrollRowOwnerMeasurements] = [:]
    private var nextRowOwnerOrder = 0
    var rowFrameRevision: Int
    private var expectedRowFrameRevision: Int
    private var expectedMeasurementEpoch: Int
    var frameVersion = 0
    var scrollMetrics: FeedScrollMetrics?
    var metricFence = FeedScrollMetricFence()
    var pendingToken: FeedScrollMeasurementToken?
    var requiresWatchdogCancellation = false
    private var acceptsIngress = true
    private var requiresFreshMeasurements = false
    private var receivedViewportSinceReset = false
    private var receivedMetricsSinceReset = false
    private var receivedRowSinceReset = false

    init(layoutRevision: Int, measurementEpoch: Int = 0) {
        rowFrameRevision = layoutRevision
        expectedRowFrameRevision = layoutRevision
        expectedMeasurementEpoch = measurementEpoch
    }

    func acceptViewportFrame(_ frame: CGRect, measurementEpoch: Int = 0) -> Bool {
        guard acceptsIngress,
              measurementEpoch == expectedMeasurementEpoch,
              viewportFrame != frame
        else {
            return false
        }

        viewportFrame = frame
        receivedViewportSinceReset = receivedViewportSinceReset || !frame.isEmpty
        frameVersion &+= 1
        return true
    }

    func acceptScrollMetrics(_ metrics: FeedScrollMetrics, measurementEpoch: Int = 0) -> Bool {
        guard acceptsIngress,
              measurementEpoch == expectedMeasurementEpoch,
              scrollMetrics != metrics
        else {
            return false
        }

        scrollMetrics = metrics
        receivedMetricsSinceReset = receivedMetricsSinceReset || metrics.viewportHeight > 0
        metricFence.observeFreshMetrics()
        requiresWatchdogCancellation = true
        return true
    }

    func prepareForLayoutRevision(_ revision: Int) {
        guard expectedRowFrameRevision != revision || rowFrameRevision != revision || !rowFrames.isEmpty else {
            return
        }

        expectedRowFrameRevision = revision
        rowFrameRevision = revision
        clearRowMeasurements()
        receivedRowSinceReset = false
        frameVersion &+= 1
    }

    func activateIngress(measurementEpoch: Int = 0) {
        expectedMeasurementEpoch = measurementEpoch
        acceptsIngress = true
    }

    func clearForDisappearance(layoutRevision: Int) {
        acceptsIngress = false
        viewportFrame = .zero
        clearRowMeasurements()
        rowFrameRevision = layoutRevision
        expectedRowFrameRevision = layoutRevision
        scrollMetrics = nil
        metricFence.invalidate()
        pendingToken = nil
        requiresWatchdogCancellation = false
        requiresFreshMeasurements = true
        receivedViewportSinceReset = false
        receivedMetricsSinceReset = false
        receivedRowSinceReset = false
        frameVersion &+= 1
    }

    var hasCurrentLayoutRowIngress: Bool {
        receivedRowSinceReset
    }

    var measurementEpoch: Int {
        expectedMeasurementEpoch
    }

    var isReadyForPendingRestoration: Bool {
        hasCurrentLayoutRowIngress
            && (!requiresFreshMeasurements
                || (receivedViewportSinceReset && receivedMetricsSinceReset))
    }

    func consumeWatchdogCancellation() -> Bool {
        defer { requiresWatchdogCancellation = false }
        return requiresWatchdogCancellation
    }

    func resetMetricFence() {
        metricFence.reset()
        requiresWatchdogCancellation = false
    }

    private func clearRowMeasurements() {
        rowFrames.removeAll()
        rowOwners.removeAll()
        rowOwnerMeasurements.removeAll()
    }

    private func persist(_ measurements: FeedScrollRowOwnerMeasurements, for id: ID) {
        if measurements.isEmpty {
            rowOwnerMeasurements.removeValue(forKey: id)
        } else {
            rowOwnerMeasurements[id] = measurements
        }
    }
}

extension FeedScrollMeasurementBuffer {
    func acceptRowFrame(
        _ rawID: AnyHashable,
        owner: UUID,
        measurement: FeedAnchorRowGeometry
    ) -> Bool {
        guard acceptsIngress,
              measurement.layoutRevision == expectedRowFrameRevision,
              measurement.measurementEpoch == expectedMeasurementEpoch,
              let id = rawID.base as? ID
        else {
            return false
        }

        var owners = rowOwnerMeasurements[id, default: .init()]
        guard let startsNewLifetime = owners.beginAppearance(
            owner: owner,
            generation: measurement.appearanceGeneration,
            nextOrder: &nextRowOwnerOrder
        ) else {
            return false
        }
        let ownerFrameChanged = owners.frames[owner] != measurement.frame
        owners.frames[owner] = measurement.frame
        owners.activeGenerations[owner] = measurement.appearanceGeneration
        persist(owners, for: id)

        guard let currentOwner = owners.currentOwner,
              let currentFrame = owners.frames[currentOwner]
        else {
            return false
        }
        let canonicalFrameChanged = rowOwners[id] != currentOwner || rowFrames[id] != currentFrame
        guard startsNewLifetime || ownerFrameChanged && canonicalFrameChanged else {
            return false
        }

        rowFrames[id] = currentFrame
        rowOwners[id] = currentOwner
        rowFrameRevision = measurement.layoutRevision
        receivedRowSinceReset = receivedRowSinceReset || !currentFrame.isEmpty
        frameVersion &+= 1
        return true
    }

    func removeRowFrame(
        _ rawID: AnyHashable,
        owner: UUID,
        layoutRevision: Int,
        measurementEpoch: Int,
        appearanceGeneration: Int
    ) -> Bool {
        guard acceptsIngress,
              layoutRevision == expectedRowFrameRevision,
              measurementEpoch == expectedMeasurementEpoch,
              let id = rawID.base as? ID,
              var owners = rowOwnerMeasurements[id],
              owners.remove(owner: owner, generation: appearanceGeneration)
        else {
            return false
        }
        persist(owners, for: id)

        let nextOwner = owners.currentOwner
        let nextFrame = nextOwner.flatMap { owners.frames[$0] }
        guard rowOwners[id] != nextOwner || rowFrames[id] != nextFrame else {
            return false
        }

        if let nextOwner, let nextFrame {
            rowOwners[id] = nextOwner
            rowFrames[id] = nextFrame
        } else {
            rowOwners.removeValue(forKey: id)
            rowFrames.removeValue(forKey: id)
        }
        frameVersion &+= 1
        return true
    }
}
