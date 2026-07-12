import SwiftUI
import UIKit

@MainActor
struct FeedScrollMetricsProbe: UIViewRepresentable {
    let measurementEpoch: Int
    let receive: @MainActor (FeedScrollMetrics, Int) -> Void

    func makeUIView(context _: Context) -> FeedScrollMetricsProbeView {
        let view = FeedScrollMetricsProbeView()
        view.receive = receive
        view.updateMeasurementEpoch(measurementEpoch)
        return view
    }

    func updateUIView(_ view: FeedScrollMetricsProbeView, context _: Context) {
        view.receive = receive
        view.updateMeasurementEpoch(measurementEpoch)
    }

    static func dismantleUIView(_ view: FeedScrollMetricsProbeView, coordinator _: ()) {
        view.prepareForDismantle()
    }
}

@MainActor
final class FeedScrollMetricsProbeView: UIView {
    var receive: (@MainActor (FeedScrollMetrics, Int) -> Void)?
    private weak var observedScrollView: UIScrollView?
    private var observations = [NSKeyValueObservation]()
    private var measurementEpoch = 0
    private var observationGeneration = 0

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview == nil {
            disconnect()
        } else {
            refresh()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            disconnect()
        } else {
            refresh()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refresh()
    }

    func updateMeasurementEpoch(_ measurementEpoch: Int) {
        guard self.measurementEpoch != measurementEpoch else {
            refresh()
            return
        }

        disconnect()
        self.measurementEpoch = measurementEpoch
        refresh()
    }

    func refresh() {
        guard let scrollView = nearestScrollView() else {
            disconnect()
            return
        }

        if observedScrollView !== scrollView {
            disconnect()
            observedScrollView = scrollView
            installObservations(on: scrollView)
        }

        publish()
    }

    private func installObservations(on scrollView: UIScrollView) {
        let observerEpoch = measurementEpoch
        let observerGeneration = observationGeneration
        installObservation(
            scrollView,
            \.contentOffset,
            options: [.initial, .new],
            sourceEpoch: observerEpoch,
            observationGeneration: observerGeneration
        )
        installObservation(
            scrollView,
            \.contentSize,
            options: [.new],
            sourceEpoch: observerEpoch,
            observationGeneration: observerGeneration
        )
        installObservation(
            scrollView,
            \.contentInset,
            options: [.new],
            sourceEpoch: observerEpoch,
            observationGeneration: observerGeneration
        )
        installObservation(
            scrollView,
            \.adjustedContentInset,
            options: [.new],
            sourceEpoch: observerEpoch,
            observationGeneration: observerGeneration
        )
        installObservation(
            scrollView,
            \.bounds,
            options: [.new],
            sourceEpoch: observerEpoch,
            observationGeneration: observerGeneration
        )
    }

    private func installObservation<Value>(
        _ scrollView: UIScrollView,
        _ keyPath: KeyPath<UIScrollView, Value>,
        options: NSKeyValueObservingOptions,
        sourceEpoch: Int,
        observationGeneration: Int
    ) {
        observations.append(
            scrollView.observe(keyPath, options: options) { [weak self] sourceScrollView, _ in
                Task { @MainActor [weak self, weak sourceScrollView] in
                    guard let sourceScrollView else { return }
                    self?.publish(
                        from: sourceScrollView,
                        sourceEpoch: sourceEpoch,
                        observationGeneration: observationGeneration
                    )
                }
            }
        )
    }

    private func nearestScrollView() -> UIScrollView? {
        var candidate = superview
        while let current = candidate {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            candidate = current.superview
        }
        return nil
    }

    private func publish(
        from sourceScrollView: UIScrollView? = nil,
        sourceEpoch: Int? = nil,
        observationGeneration: Int? = nil
    ) {
        guard sourceEpoch == nil || sourceEpoch == measurementEpoch,
              observationGeneration == nil || observationGeneration == self.observationGeneration,
              let scrollView = sourceScrollView ?? observedScrollView,
              observedScrollView === scrollView,
              scrollView.bounds.height > 0
        else {
            return
        }

        let publicationEpoch = sourceEpoch ?? measurementEpoch
        receive?(
            FeedScrollMetrics(
                contentOffsetY: scrollView.contentOffset.y,
                topInset: scrollView.adjustedContentInset.top,
                bottomInset: scrollView.adjustedContentInset.bottom,
                contentHeight: scrollView.contentSize.height,
                viewportHeight: scrollView.bounds.height
            ),
            publicationEpoch
        )
    }

    private func disconnect() {
        observationGeneration &+= 1
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        observedScrollView = nil
    }

    fileprivate func prepareForDismantle() {
        receive = nil
        disconnect()
    }
}
