@testable import HackersPub
import Observation
import SwiftUI
import UIKit

struct MountedFeedAnchorRestorationResult {
    let restoration: FeedScrollAnchorPolicy<String>.Restoration
    let restored: FeedViewportSnapshot<String>
    let contentOffsetY: CGFloat
    let observedCommandPhases: Set<String>
    let observedCommands: [ObservedFeedScrollCommand]
    let issuedTargetY: CGFloat?
    let topInset: CGFloat?
    let bottomInset: CGFloat?
    let contentHeight: CGFloat?
    let viewportHeight: CGFloat?
    let bindingAcknowledged: Bool
    let capturedContentOffsetY: CGFloat
    let capturedTopInset: CGFloat?
    let capturedBottomInset: CGFloat?
    let capturedContentHeight: CGFloat?
    let capturedViewportHeight: CGFloat?
}

struct ObservedFeedScrollCommand: Equatable {
    let phase: String
    let commandFrameGeneration: Int
    let commandFrameTimestamp: TimeInterval
}

enum MountedFeedAnchorFixtureError: Error {
    case scrollViewNotMounted
    case manualCommandNotObserved(String)
    case manualMeasurementNotPublished
}

@Observable
@MainActor
final class MountedFeedAnchorModel {
    struct Row: Identifiable {
        let id: String
        let height: CGFloat
    }

    var rows: [Row]
    var viewport = FeedViewportSnapshot<String>()
    var restoration: FeedScrollAnchorPolicy<String>.Restoration?
    @ObservationIgnored var latestDiagnostics: FeedAnchorScrollDiagnostics<String>?
    @ObservationIgnored var observedCommandPhases = Set<String>()
    @ObservationIgnored var observedCommands = [ObservedFeedScrollCommand]()
    @ObservationIgnored var permitsMeasurementMetrics = true

    init(rows: [Row], viewport: FeedViewportSnapshot<String> = .init()) {
        self.rows = rows
        self.viewport = viewport
    }
}

@MainActor
final class MountedFeedAnchorFixture {
    let model: MountedFeedAnchorModel
    let controller: UIHostingController<MountedFeedAnchorHarness>
    let window: UIWindow
    let rootController: UIViewController
    private let heightConstraint: NSLayoutConstraint
    private let attachmentConstraints: [NSLayoutConstraint]
    private var isAttached = true

    init(
        measurementFrameScheduler: ManualFeedScrollCommandFrameScheduler? = nil,
        commandFrameScheduler: ManualFeedScrollCommandFrameScheduler? = nil,
        usesNestedRowLayout: Bool = false,
        contentTopInset: CGFloat = 0,
        contentBottomInset: CGFloat = 0,
        initialViewport: FeedViewportSnapshot<String> = .init(),
        initialRestoration: FeedScrollAnchorPolicy<String>.Restoration? = nil
    ) {
        var rows = [MountedFeedAnchorModel.Row]()
        rows.append(.init(id: "post-1", height: 72))
        rows.append(.init(id: "post-2", height: 113))
        rows.append(.init(id: "post-3", height: 64))
        rows.append(.init(id: "post-4", height: 97))
        rows.append(.init(id: "post-5", height: 81))
        let model = MountedFeedAnchorModel(rows: rows, viewport: initialViewport)
        model.restoration = initialRestoration
        let controller = UIHostingController(
            rootView: MountedFeedAnchorHarness(
                model: model,
                measurementFrameScheduler: measurementFrameScheduler,
                usesNestedRowLayout: usesNestedRowLayout,
                contentTopInset: contentTopInset,
                contentBottomInset: contentBottomInset,
                commandFrameScheduler: commandFrameScheduler
            )
        )
        let window = mountedWindow()
        let rootController = UIViewController()
        rootController.addChild(controller)
        rootController.view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = controller.view.widthAnchor.constraint(equalToConstant: 320)
        let heightConstraint = controller.view.heightAnchor.constraint(equalToConstant: 180)
        var attachmentConstraints = [NSLayoutConstraint]()
        attachmentConstraints.append(widthConstraint)
        attachmentConstraints.append(heightConstraint)
        attachmentConstraints.append(
            controller.view.centerXAnchor.constraint(equalTo: rootController.view.centerXAnchor)
        )
        attachmentConstraints.append(
            controller.view.centerYAnchor.constraint(equalTo: rootController.view.centerYAnchor)
        )
        NSLayoutConstraint.activate(attachmentConstraints)
        controller.didMove(toParent: rootController)
        window.rootViewController = rootController
        window.makeKeyAndVisible()

        self.model = model
        self.controller = controller
        self.window = window
        self.rootController = rootController
        self.heightConstraint = heightConstraint
        self.attachmentConstraints = attachmentConstraints
    }

    func waitForScrollView() async throws -> UIScrollView {
        for _ in 0 ..< 120 {
            await awaitNextDisplayFrame()
            if let scrollView = firstScrollView(in: controller.view) {
                return scrollView
            }
        }
        throw MountedFeedAnchorFixtureError.scrollViewNotMounted
    }

    func resizeViewport(height: CGFloat) {
        heightConstraint.constant = height
        rootController.view.setNeedsLayout()
        controller.view.setNeedsLayout()
    }

    func detachAdapter() {
        guard isAttached else { return }

        controller.willMove(toParent: nil)
        NSLayoutConstraint.deactivate(attachmentConstraints)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        isAttached = false
    }

    func reattachAdapter() {
        guard !isAttached else { return }

        rootController.addChild(controller)
        rootController.view.addSubview(controller.view)
        NSLayoutConstraint.activate(attachmentConstraints)
        controller.didMove(toParent: rootController)
        rootController.view.setNeedsLayout()
        controller.view.setNeedsLayout()
        isAttached = true
    }

    func dismantle() {
        detachAdapter()
        window.rootViewController = nil
        window.isHidden = true
    }
}

@MainActor
private func mountedWindow() -> UIWindow {
    let connectedWindowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    guard let windowScene = connectedWindowScene else {
        preconditionFailure("Mounted feed tests require a connected UIWindowScene.")
    }
    return UIWindow(windowScene: windowScene)
}

struct MountedFeedAnchorHarness: View {
    @Bindable var model: MountedFeedAnchorModel
    private let measurementFrameScheduler: (any FeedScrollCommandFrameScheduling)?
    private let commandFrameScheduler: (any FeedScrollCommandFrameScheduling)?
    private let usesNestedRowLayout: Bool
    private let contentTopInset: CGFloat
    private let contentBottomInset: CGFloat

    init(
        model: MountedFeedAnchorModel,
        measurementFrameScheduler: (any FeedScrollCommandFrameScheduling)? = nil,
        usesNestedRowLayout: Bool = false,
        contentTopInset: CGFloat = 0,
        contentBottomInset: CGFloat = 0,
        commandFrameScheduler: (any FeedScrollCommandFrameScheduling)? = nil
    ) {
        self.model = model
        self.measurementFrameScheduler = measurementFrameScheduler
        self.commandFrameScheduler = commandFrameScheduler
        self.usesNestedRowLayout = usesNestedRowLayout
        self.contentTopInset = contentTopInset
        self.contentBottomInset = contentBottomInset
    }

    var body: some View {
        FeedAnchorScrollView(
            viewport: $model.viewport,
            restoration: $model.restoration,
            onDiagnostic: recordDiagnostic,
            measurementFrameScheduler: measurementFrameScheduler,
            commandFrameScheduler: commandFrameScheduler,
            measurementMetricsAdmission: { _ in model.permitsMeasurementMetrics },
            content: {
                LazyVStack(spacing: 0) {
                    ForEach(model.rows) { row in
                        rowView(for: row)
                    }
                }
            }
        )
        .contentMargins(.top, contentTopInset, for: .scrollContent)
        .contentMargins(.bottom, contentBottomInset, for: .scrollContent)
    }

    @ViewBuilder
    private func rowView(for row: MountedFeedAnchorModel.Row) -> some View {
        if usesNestedRowLayout {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(height: row.height)
                }
            }
            .padding(.horizontal, 12)
            .feedScrollAnchor(id: row.id)
            .id(row.id)
        } else {
            Color.clear
                .frame(height: row.height)
                .feedScrollAnchor(id: row.id)
                .id(row.id)
        }
    }

    private func recordDiagnostic(_ diagnostics: FeedAnchorScrollDiagnostics<String>) {
        model.latestDiagnostics = diagnostics
        guard let phase = diagnostics.latestCommandPhase,
              let commandFrameGeneration = diagnostics.latestCommandFrameGeneration,
              let commandFrameTimestamp = diagnostics.latestCommandFrameTimestamp
        else {
            return
        }
        model.observedCommandPhases.insert(phase)
        let command = ObservedFeedScrollCommand(
            phase: phase,
            commandFrameGeneration: commandFrameGeneration,
            commandFrameTimestamp: commandFrameTimestamp
        )
        if model.observedCommands.last != command {
            model.observedCommands.append(command)
        }
    }
}
