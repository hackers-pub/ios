import SwiftUI

struct FeedAnchorScrollDiagnostics<ID: Hashable> {
    let pendingSequence: Int?
    let pendingID: ID?
    let pendingOffset: CGFloat?
    let attemptCount: Int
    let issuedTargetY: CGFloat?
    let latestCommandPhase: String?
    let latestCommandFrameGeneration: Int?
    let latestCommandFrameTimestamp: TimeInterval?
    let frameVersion: Int
    let layoutRevision: Int
    let rowFrameRevision: Int
    let measurementEpoch: Int
    let hasCurrentLayoutRowIngress: Bool
    let isReadyForPendingRestoration: Bool
    let scrollMetricGeneration: Int
    let awaitingMetricGeneration: Int?
    let rowOffsets: [FeedViewportAnchor<ID>]
    let rowGlobalFrames: [ID: CGRect]
    let viewportGlobalFrame: CGRect?
    let bindingAcknowledged: Bool
    let contentOffsetY: CGFloat?
    let topInset: CGFloat?
    let bottomInset: CGFloat?
    let contentHeight: CGFloat?
    let viewportHeight: CGFloat?

    var description: String {
        let rows = rowOffsets.map { "\($0.id):\($0.offset)" }.joined(separator: ",")
        let pending = "pending=\(String(describing: pendingSequence))/"
            + "\(String(describing: pendingID))/"
            + "\(String(describing: pendingOffset))"
        let revision = "revision=\(layoutRevision) metricGeneration=\(scrollMetricGeneration)/"
            + "\(String(describing: awaitingMetricGeneration))"
        let ingress = "rowRevision=\(rowFrameRevision) epoch=\(measurementEpoch)"
            + " rowIngress=\(hasCurrentLayoutRowIngress) ready=\(isReadyForPendingRestoration)"
        var components = [pending]
        components.append("attempts=\(attemptCount) phase=\(String(describing: latestCommandPhase))")
        components.append("commandFrame=\(String(describing: latestCommandFrameGeneration))")
        components.append("commandTimestamp=\(String(describing: latestCommandFrameTimestamp))")
        components.append("issuedY=\(String(describing: issuedTargetY)) frame=\(frameVersion)")
        components.append(revision)
        components.append(ingress)
        components.append("rows=[\(rows)] frames=\(rowGlobalFrames)")
        components.append("viewport=\(String(describing: viewportGlobalFrame))")
        components.append("bindingAcknowledged=\(bindingAcknowledged)")
        components.append("offsetY=\(String(describing: contentOffsetY))")
        components.append("topInset=\(String(describing: topInset))")
        components.append("bottomInset=\(String(describing: bottomInset))")
        components.append("contentHeight=\(String(describing: contentHeight))")
        components.append("viewportHeight=\(String(describing: viewportHeight))")
        return components.joined(separator: " ")
    }
}
