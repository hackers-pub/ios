@testable import HackersPub
import Testing
import UIKit

struct FeedScrollMetricsProbeTests {
    @Test("SOC-13: the UIKit metrics probe detaches and reattaches to the current scroll view")
    @MainActor
    func metricsProbeReattachesWithoutObservingAnOldScrollView() async throws {
        let firstScrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        firstScrollView.contentSize = CGSize(width: 320, height: 1000)
        let firstHost = UIView(frame: firstScrollView.bounds)
        firstScrollView.addSubview(firstHost)

        let probe = FeedScrollMetricsProbeView()
        var observedMetrics = [MetricsProbePublication]()
        probe.receive = { metrics, epoch in
            observedMetrics.append(.init(metrics: metrics, epoch: epoch))
        }
        firstHost.addSubview(probe)
        firstScrollView.contentOffset = CGPoint(x: 0, y: 95)

        let didReceiveFirstMetric = await waitForDisplayFrames(
            until: { observedMetrics.last?.metrics.contentOffsetY == 95 }
        )
        #expect(didReceiveFirstMetric)
        let firstMetric = try #require(observedMetrics.last)
        assertFirstScrollPublication(firstMetric)

        let countBeforeDetach = observedMetrics.count
        firstScrollView.contentOffset = CGPoint(x: 0, y: 140)
        probe.removeFromSuperview()

        let secondScrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        secondScrollView.contentSize = CGSize(width: 320, height: 900)
        let secondHost = UIView(frame: secondScrollView.bounds)
        secondScrollView.addSubview(secondHost)
        secondHost.addSubview(probe)
        await drainQueuedMainActorTasks()

        let postDetachPublications = observedMetrics.dropFirst(countBeforeDetach)
        #expect(!postDetachPublications.isEmpty)
        #expect(postDetachPublications.allSatisfy(isSecondScrollInitialPublication))
        let baselineAfterSecondInitial = observedMetrics.count
        secondScrollView.contentOffset = CGPoint(x: 0, y: 203)

        let didReceiveFreshMetric = await waitForDisplayFrames(
            until: { observedMetrics.last?.metrics.contentOffsetY == 203 }
        )
        #expect(didReceiveFreshMetric)
        #expect(observedMetrics.count > baselineAfterSecondInitial)
        let secondMetric = try #require(observedMetrics.last)
        assertSecondScrollPublication(secondMetric, offsetY: 203)
        #expect(observedMetrics.dropFirst(countBeforeDetach).allSatisfy(isSecondScrollPublication))

        probe.removeFromSuperview()
        let finalCount = observedMetrics.count
        secondScrollView.contentOffset = CGPoint(x: 0, y: 250)
        await drainQueuedMainActorTasks()
        #expect(observedMetrics.count == finalCount)
    }

    @Test("SOC-13: a queued old-epoch KVO callback cannot publish after the epoch changes")
    @MainActor
    func metricsProbeDropsQueuedOldEpochCallback() async {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        scrollView.contentSize = CGSize(width: 320, height: 1000)
        let host = UIView(frame: scrollView.bounds)
        scrollView.addSubview(host)

        let probe = FeedScrollMetricsProbeView()
        var observedMetrics = [MetricsProbePublication]()
        probe.receive = { metrics, epoch in
            observedMetrics.append(.init(metrics: metrics, epoch: epoch))
        }
        host.addSubview(probe)
        scrollView.contentOffset = CGPoint(x: 0, y: 95)
        let didReceiveInitialMetric = await waitForDisplayFrames(
            until: { observedMetrics.last?.metrics.contentOffsetY == 95 }
        )
        #expect(didReceiveInitialMetric)

        let countBeforeEpochChange = observedMetrics.count
        scrollView.contentOffset = CGPoint(x: 0, y: 140)
        probe.updateMeasurementEpoch(1)
        await drainQueuedMainActorTasks()

        let postEpochPublications = observedMetrics.dropFirst(countBeforeEpochChange)
        #expect(!postEpochPublications.isEmpty)
        #expect(postEpochPublications.allSatisfy { $0.epoch == 1 })
        #expect(
            postEpochPublications.allSatisfy {
                $0.metrics.contentOffsetY == 140
                    && $0.metrics.contentHeight == 1000
                    && $0.metrics.viewportHeight == 180
            }
        )
        let baselineAfterCurrentEpoch = observedMetrics.count
        scrollView.contentOffset = CGPoint(x: 0, y: 203)

        let didReceiveCurrentEpochMetric = await waitForDisplayFrames(
            until: { observedMetrics.last?.metrics.contentOffsetY == 203 }
        )
        #expect(didReceiveCurrentEpochMetric)
        #expect(observedMetrics.count > baselineAfterCurrentEpoch)
        #expect(observedMetrics.last?.epoch == 1)
    }

    @Test("SOC-13: representable dismantling suppresses queued KVO and releases its receive closure")
    @MainActor
    func metricsProbeDismantleSuppressesQueuedKVOCallback() async {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        scrollView.contentSize = CGSize(width: 320, height: 1000)
        let host = UIView(frame: scrollView.bounds)
        scrollView.addSubview(host)

        let probe = FeedScrollMetricsProbeView()
        var observedMetrics = [MetricsProbePublication]()
        probe.receive = { metrics, epoch in
            observedMetrics.append(.init(metrics: metrics, epoch: epoch))
        }
        host.addSubview(probe)
        scrollView.contentOffset = CGPoint(x: 0, y: 95)
        let didReceiveInitialMetric = await waitForDisplayFrames(
            until: { observedMetrics.last?.metrics.contentOffsetY == 95 }
        )
        #expect(didReceiveInitialMetric)

        weak var releasedSentinel: MetricsProbeReceiveSentinel?
        do {
            let sentinel = MetricsProbeReceiveSentinel()
            releasedSentinel = sentinel
            probe.receive = { [sentinel] metrics, epoch in
                observedMetrics.append(.init(metrics: metrics, epoch: epoch))
                withExtendedLifetime(sentinel) {}
            }
        }
        #expect(releasedSentinel != nil)
        let countBeforeDismantle = observedMetrics.count
        scrollView.contentOffset = CGPoint(x: 0, y: 140)
        FeedScrollMetricsProbe.dismantleUIView(probe, coordinator: ())
        await drainQueuedMainActorTasks()
        #expect(observedMetrics.count == countBeforeDismantle)
        #expect(releasedSentinel == nil)

        scrollView.contentOffset = CGPoint(x: 0, y: 203)
        await drainQueuedMainActorTasks()
        #expect(observedMetrics.count == countBeforeDismantle)
    }
}

private struct MetricsProbePublication {
    let metrics: FeedScrollMetrics
    let epoch: Int
}

private final class MetricsProbeReceiveSentinel {}

private func assertFirstScrollPublication(_ publication: MetricsProbePublication) {
    #expect(publication.metrics.contentOffsetY == 95)
    #expect(publication.metrics.contentHeight == 1000)
    #expect(publication.metrics.viewportHeight == 180)
    #expect(publication.epoch == 0)
}

private func assertSecondScrollPublication(
    _ publication: MetricsProbePublication,
    offsetY: CGFloat
) {
    #expect(publication.metrics.contentOffsetY == offsetY)
    #expect(isSecondScrollPublication(publication))
}

private func isSecondScrollInitialPublication(_ publication: MetricsProbePublication) -> Bool {
    publication.metrics.contentOffsetY == 0 && isSecondScrollPublication(publication)
}

private func isSecondScrollPublication(_ publication: MetricsProbePublication) -> Bool {
    publication.metrics.contentHeight == 900
        && publication.metrics.viewportHeight == 120
        && publication.epoch == 0
}

@MainActor
private func drainQueuedMainActorTasks() async {
    for _ in 0 ..< 4 {
        await Task.yield()
    }
}
