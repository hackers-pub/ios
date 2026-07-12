import Foundation
@testable import HackersPub
import Testing

@MainActor
struct TimelineLaunchNetworkPolicyTests {
    @Test func noLiveRootNetworkModeFeedsOnlyTheControllerAutomaticInitialLoadGate() throws {
        let source = try source(named: "HackersPub/Views/TimelineView.swift")

        #expect(source.contains("initialLoadEnabled: !UITestLaunchConfiguration.disablesRootTimelineNetwork"))
        #expect(!source.contains("LocalTimelineInitialLoadPolicy"))
    }

    @Test func noLiveRootNetworkUsesTheNamespacedUITestLaunchArgument() {
        #expect(UITestLaunchConfiguration.disablesRootTimelineNetwork(
            arguments: ["-com.hackerspub.ui-test.no-live-root-network"]
        ))
        #expect(!UITestLaunchConfiguration.disablesRootTimelineNetwork(arguments: []))
    }

    private func source(named relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
