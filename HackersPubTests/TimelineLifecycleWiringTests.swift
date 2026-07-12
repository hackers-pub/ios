import Foundation
import Testing

struct TimelineLifecycleWiringTests {
    @Test func timelineViewsUseOneTypedControllerPerFeed() throws {
        let timelineView = try source(named: "HackersPub/Views/TimelineView.swift")
        let controller = try source(named: "HackersPub/Views/TimelineFeedController.swift")

        #expect(timelineView.occurrenceCount(of: "@State private var controller = TimelineFeedController<") == 3)
        #expect(timelineView.occurrenceCount(of: "await controller.supervise") >= 3)
        #expect(timelineView.occurrenceCount(of: "controller.cancelAll()") == 3)
        #expect(timelineView.occurrenceCount(of: "controller.requestRefresh()") == 3)
        #expect(!timelineView.contains("TimelineViewTaskOwner"))
        #expect(!timelineView.contains("RefreshReplayDriver"))
        #expect(!timelineView.contains("loadInitialPosts"))
        #expect(controller.occurrenceCount(of: "TimelineRefreshCoordinator(") == 1)
        #expect(controller.occurrenceCount(of: "refreshReplayDriver.withActiveOwner(owner)") >= 4)
        #expect(!controller.contains("refreshReplayDriver.activateOwner()"))
        #expect(!controller.contains("scheduleNotificationRefreshIfNeeded"))
        #expect(!controller.contains("beginNotificationRefreshIfNeeded"))
        #expect(!controller.contains("shouldRefresh"))
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

private extension String {
    func occurrenceCount(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
}
