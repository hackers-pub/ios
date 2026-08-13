import SwiftUI

private struct FeedAnchorLayoutRevisionKey: EnvironmentKey {
    static let defaultValue = 0
}

private struct FeedAnchorMeasurementEpochKey: EnvironmentKey {
    static let defaultValue = 0
}

private extension EnvironmentValues {
    var feedAnchorLayoutRevision: Int {
        get { self[FeedAnchorLayoutRevisionKey.self] }
        set { self[FeedAnchorLayoutRevisionKey.self] = newValue }
    }

    var feedAnchorMeasurementEpoch: Int {
        get { self[FeedAnchorMeasurementEpochKey.self] }
        set { self[FeedAnchorMeasurementEpochKey.self] = newValue }
    }
}

private struct FeedAnchorRowMeasurementSink {
    let receive: @MainActor (AnyHashable, UUID, FeedAnchorRowGeometry) -> Void
    let remove: @MainActor (AnyHashable, UUID, Int, Int, Int) -> Void
}

private struct FeedAnchorRowMeasurementSinkKey: EnvironmentKey {
    static let defaultValue: FeedAnchorRowMeasurementSink? = nil
}

private extension EnvironmentValues {
    var feedAnchorRowMeasurementSink: FeedAnchorRowMeasurementSink? {
        get { self[FeedAnchorRowMeasurementSinkKey.self] }
        set { self[FeedAnchorRowMeasurementSinkKey.self] = newValue }
    }
}

private struct FeedScrollAnchorRowMeasurementObserver: View {
    let rawID: AnyHashable
    let owner: UUID
    let stamp: FeedAnchorRowMeasurementStamp
    let sink: FeedAnchorRowMeasurementSink?

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    publish(proxy.frame(in: .global))
                }
                .onGeometryChange(for: CGRect.self) { geometryProxy in
                    geometryProxy.frame(in: .global)
                } action: { publish($0) }
                .onChange(of: stamp) { _, _ in
                    publish(proxy.frame(in: .global))
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @MainActor private func publish(_ frame: CGRect) {
        sink?.receive(
            rawID,
            owner,
            FeedAnchorRowGeometry(
                frame: frame,
                layoutRevision: stamp.layoutRevision,
                measurementEpoch: stamp.measurementEpoch,
                appearanceGeneration: stamp.appearanceGeneration
            )
        )
    }
}

private struct FeedScrollAnchorRowModifier<ID: Hashable>: ViewModifier {
    let id: ID
    @State private var instanceOwner = UUID()
    @State private var appearanceGeneration = 0
    @Environment(\.feedAnchorLayoutRevision) private var layoutRevision
    @Environment(\.feedAnchorMeasurementEpoch) private var measurementEpoch
    @Environment(\.feedAnchorRowMeasurementSink) private var measurementSink

    func body(content: Content) -> some View {
        let measurementStamp = FeedAnchorRowMeasurementStamp(
            layoutRevision: layoutRevision,
            measurementEpoch: measurementEpoch,
            appearanceGeneration: appearanceGeneration
        )
        return content
            .background {
                FeedScrollAnchorRowMeasurementObserver(
                    rawID: AnyHashable(id),
                    owner: instanceOwner,
                    stamp: measurementStamp,
                    sink: measurementSink
                )
            }
            .onDisappear {
                measurementSink?.remove(
                    AnyHashable(id),
                    instanceOwner,
                    measurementStamp.layoutRevision,
                    measurementStamp.measurementEpoch,
                    measurementStamp.appearanceGeneration
                )
            }
            .onAppear {
                appearanceGeneration &+= 1
            }
    }
}

extension View {
    func feedScrollAnchor(id: some Hashable) -> some View {
        modifier(FeedScrollAnchorRowModifier(id: id))
    }
}

/// Production scroll adapter for semantic row frames and one post-layout restoration delta.
@MainActor
struct FeedAnchorScrollView<ID: Hashable & Sendable, Content: View>: View {
    @Binding var viewport: FeedViewportSnapshot<ID>
    @Binding var restoration: FeedScrollAnchorPolicy<ID>.Restoration?
    @State var scrollPosition: ScrollPosition
    @State var initialAnchor: FeedViewportAnchor<ID>?
    @State var pendingRestoration: FeedScrollAnchorPolicy<ID>.Restoration?
    @State var pendingMaterializationSequence: Int?
    @State var attemptTracker = FeedScrollRestorationAttemptTracker()
    @State var watchdogToken: FeedScrollCommandToken?
    @State var watchdogTask: Task<Void, Never>?
    @State var measurementBuffer: FeedScrollMeasurementBuffer<ID>
    @State var measurementRefreshToken = 0
    @State var measurementFrameScheduler: any FeedScrollCommandFrameScheduling
    @State var commandFrameScheduler: any FeedScrollCommandFrameScheduling
    @State var pendingCommand: FeedScrollCommandExecutionToken<ID>?
    @State var latestIssuedTargetY: CGFloat?
    @State var latestCommandPhase: String?
    @State var latestCommandFrameGeneration: Int?
    @State var latestCommandFrameTimestamp: TimeInterval?
    let onDiagnostic: ((FeedAnchorScrollDiagnostics<ID>) -> Void)?
    let measurementMetricsAdmission: (@MainActor (FeedScrollMetrics) -> Bool)?
    let watchdogTimeout: Duration
    private let content: Content

    init(
        viewport: Binding<FeedViewportSnapshot<ID>>,
        restoration: Binding<FeedScrollAnchorPolicy<ID>.Restoration?>,
        onDiagnostic: ((FeedAnchorScrollDiagnostics<ID>) -> Void)? = nil,
        watchdogTimeout: Duration = .seconds(1),
        measurementFrameScheduler: (any FeedScrollCommandFrameScheduling)? = nil,
        commandFrameScheduler: (any FeedScrollCommandFrameScheduling)? = nil,
        measurementMetricsAdmission: (@MainActor (FeedScrollMetrics) -> Bool)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        _viewport = viewport
        _restoration = restoration
        self.onDiagnostic = onDiagnostic
        self.measurementMetricsAdmission = measurementMetricsAdmission
        self.watchdogTimeout = watchdogTimeout
        self.content = content()
        let pendingRestoration = restoration.wrappedValue
        _measurementBuffer = State(
            initialValue: FeedScrollMeasurementBuffer(
                layoutRevision: pendingRestoration?.sequence ?? 0
            )
        )
        _measurementFrameScheduler = State(
            initialValue: measurementFrameScheduler ?? FeedScrollCommandDisplayLinkScheduler()
        )
        _commandFrameScheduler = State(
            initialValue: commandFrameScheduler ?? FeedScrollCommandDisplayLinkScheduler()
        )

        let savedAnchor = pendingRestoration == nil && !viewport.wrappedValue.isAtTop
            ? viewport.wrappedValue.primaryAnchor
            : nil
        _initialAnchor = State(initialValue: savedAnchor)
        _pendingRestoration = State(initialValue: pendingRestoration)
        _pendingMaterializationSequence = State(initialValue: pendingRestoration?.sequence)
        if let savedAnchor {
            _scrollPosition = State(
                initialValue: ScrollPosition(id: savedAnchor.id, anchor: .top)
            )
        } else {
            _scrollPosition = State(initialValue: ScrollPosition(idType: ID.self, edge: .top))
        }
    }

    var body: some View {
        let currentMeasurementEpoch = measurementRefreshToken
        ScrollView {
            content
                .background {
                    FeedScrollMetricsProbe(
                        measurementEpoch: currentMeasurementEpoch,
                        receive: receiveScrollMetrics
                    )
                }
                .environment(\.feedAnchorLayoutRevision, layoutRevision)
                .environment(\.feedAnchorMeasurementEpoch, currentMeasurementEpoch)
                .environment(\.feedAnchorRowMeasurementSink, rowMeasurementSink)
                .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition)
        .onGeometryChange(for: FeedAnchorViewportGeometry.self) { proxy in
            FeedAnchorViewportGeometry(
                frame: proxy.frame(in: .global),
                measurementEpoch: currentMeasurementEpoch
            )
        } action: { measurement in
            receiveViewportFrame(
                measurement.frame,
                measurementEpoch: measurement.measurementEpoch
            )
        }
        .onChange(of: restoration?.sequence) { _, _ in
            handleRestorationChange()
        }
        .onDisappear(perform: handleDisappear)
        .onAppear(perform: handleAppear)
        .overlay(alignment: .bottomTrailing) {
            if attemptTracker.requiresVisibleRetry {
                retryButton
            }
        }
    }
}

extension FeedAnchorScrollView {
    private var rowMeasurementSink: FeedAnchorRowMeasurementSink {
        FeedAnchorRowMeasurementSink(
            receive: { rawID, owner, measurement in
                receiveRowFrame(rawID, owner: owner, measurement: measurement)
            },
            remove: { rawID, owner, revision, measurementEpoch, appearanceGeneration in
                removeRowFrame(
                    rawID,
                    owner: owner,
                    layoutRevision: revision,
                    measurementEpoch: measurementEpoch,
                    appearanceGeneration: appearanceGeneration
                )
            }
        )
    }

    var retryButton: some View {
        Button(action: retryPendingRestoration) {
            Label(
                NSLocalizedString("feed.restorePosition", comment: "Restore reading position"),
                systemImage: "arrow.counterclockwise"
            )
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .accessibilityLabel(
            NSLocalizedString("feed.restorePosition", comment: "Restore reading position")
        )
    }

    func receiveScrollMetrics(_ metrics: FeedScrollMetrics, measurementEpoch: Int) {
        guard measurementMetricsAdmission?(metrics) ?? true else {
            return
        }
        guard measurementBuffer.acceptScrollMetrics(
            metrics,
            measurementEpoch: measurementEpoch
        ) else {
            return
        }
        scheduleMeasurementReconciliation()
    }

    func receiveViewportFrame(_ frame: CGRect, measurementEpoch: Int) {
        guard measurementBuffer.acceptViewportFrame(
            frame,
            measurementEpoch: measurementEpoch
        ) else {
            return
        }
        scheduleMeasurementReconciliation()
    }

    func receiveRowFrame(
        _ rawID: AnyHashable,
        owner: UUID,
        measurement: FeedAnchorRowGeometry
    ) {
        guard measurementBuffer.acceptRowFrame(rawID, owner: owner, measurement: measurement) else {
            return
        }
        scheduleMeasurementReconciliation()
    }

    func removeRowFrame(
        _ rawID: AnyHashable,
        owner: UUID,
        layoutRevision: Int,
        measurementEpoch: Int,
        appearanceGeneration: Int
    ) {
        guard measurementBuffer.removeRowFrame(
            rawID,
            owner: owner,
            layoutRevision: layoutRevision,
            measurementEpoch: measurementEpoch,
            appearanceGeneration: appearanceGeneration
        ) else {
            return
        }
        scheduleMeasurementReconciliation()
    }

    func handleRestorationChange() {
        guard let restoration else {
            if pendingRestoration != nil {
                pendingRestoration = nil
                attemptTracker.reset()
            }
            pendingMaterializationSequence = nil
            measurementBuffer.prepareForLayoutRevision(0)
            measurementBuffer.resetMetricFence()
            cancelScheduledWork()
            cancelWatchdog()
            return
        }
        guard pendingRestoration?.sequence != restoration.sequence else { return }

        pendingRestoration = restoration
        pendingMaterializationSequence = restoration.sequence
        attemptTracker.reset()
        measurementBuffer.prepareForLayoutRevision(restoration.sequence)
        refreshMeasurementIngress()
        measurementBuffer.resetMetricFence()
        cancelScheduledWork()
        cancelWatchdog()
        initialAnchor = nil
        reportDiagnostics()
        scheduleMeasurementReconciliation()
    }

    func handleDisappear() {
        pendingMaterializationSequence = pendingRestoration?.sequence
        measurementBuffer.clearForDisappearance(layoutRevision: layoutRevision)
        attemptTracker.reset()
        cancelScheduledWork()
        cancelWatchdog()
    }

    func handleAppear() {
        refreshMeasurementIngress()
    }

    func refreshMeasurementIngress() {
        measurementRefreshToken &+= 1
        measurementBuffer.activateIngress(measurementEpoch: measurementRefreshToken)
    }

    func retryPendingRestoration() {
        attemptTracker.reset()
        measurementBuffer.resetMetricFence()
        cancelScheduledWork()
        cancelWatchdog()
        scheduleMeasurementReconciliation()
    }

    func updateViewportSnapshot() {
        let measurement = measurementBuffer
        guard measurement.hasCurrentLayoutRowIngress,
              measurement.rowFrameRevision == layoutRevision,
              !measurement.viewportFrame.isEmpty
        else {
            return
        }

        let visibleAnchors = measurement.rowFrames.compactMap { id, frame -> FeedViewportAnchor<ID>? in
            guard frame.maxY > measurement.viewportFrame.minY + 0.5,
                  frame.minY < measurement.viewportFrame.maxY - 0.5
            else {
                return nil
            }
            return FeedViewportAnchor(id: id, offset: frame.minY - measurement.viewportFrame.minY)
        }
        .sorted { $0.offset < $1.offset }
        let metricsReportTop = measurement.scrollMetrics.map { metrics in
            metrics.contentOffsetY <= -metrics.topInset + 0.5
        } ?? true
        let measuredRowsReportTop = !measurement.rowFrames.values.contains { frame in
            frame.minY < measurement.viewportFrame.minY - 0.5
        }
        let snapshot = FeedViewportSnapshot(
            visibleAnchors: visibleAnchors,
            isAtTop: metricsReportTop && measuredRowsReportTop
        )
        if viewport != snapshot {
            viewport = snapshot
        }
    }
}
