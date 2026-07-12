import Foundation
@testable import HackersPub
import Testing

@MainActor
struct TimelineFeedControllerTests {
    @Test func streamedInitialResponsesApplyInArrivalOrder() async {
        let fixture = TimelineFeedControllerFixture(
            initialResponses: [
                response([edge("cached")], hasNextPage: true, startCursor: "cached", endCursor: "cached"),
                response([edge("network")], hasNextPage: false, startCursor: "network", endCursor: "network")
            ]
        )
        let controller = TimelineFeedController(source: fixture.source)
        let supervisor = Task { @MainActor in
            await controller.supervise()
        }

        await waitUntil {
            fixture.initialLoadCount == 1 && controller.timelineState.edges.map(\.id) == ["network"]
        }

        #expect(!controller.timelineState.hasNextPage)
        controller.cancelAll()
        await supervisor.value
    }

    @Test func paginationUsesDirectionalCursorsAndMergesAtTheCorrectEnds() async {
        let fixture = TimelineFeedControllerFixture(
            initialResponses: [
                response(
                    [edge("a")],
                    hasPreviousPage: true,
                    hasNextPage: true,
                    startCursor: "a",
                    endCursor: "a"
                )
            ],
            olderResponse: response([edge("b")], hasNextPage: false, startCursor: "b", endCursor: "b"),
            newerResponse: response([edge("new")], hasNextPage: false, startCursor: "new", endCursor: "new")
        )
        let controller = TimelineFeedController(source: fixture.source)
        let supervisor = Task { @MainActor in
            await controller.supervise()
        }

        await waitUntil { controller.timelineState.edges.map(\.id) == ["a"] }
        #expect(controller.timelineState.canLoadNewer)
        controller.loadMore()
        await waitUntil { controller.timelineState.edges.map(\.id) == ["a", "b"] }
        controller.loadNewer()
        await waitUntil { controller.timelineState.edges.map(\.id) == ["new", "a", "b"] }

        #expect(fixture.olderCursors == ["a"])
        #expect(fixture.newerCursors == ["a"])
        controller.cancelAll()
        await supervisor.value
    }

    @Test func refreshNotificationReplaysThroughTheSharedSupervisor() async {
        let fixture = TimelineFeedControllerFixture(
            initialResponses: [
                response(
                    [edge("cached")],
                    hasNextPage: false,
                    startCursor: "cached",
                    endCursor: "cached"
                )
            ],
            refreshResponse: response([edge("fresh")], hasNextPage: false, startCursor: "fresh", endCursor: "fresh")
        )
        let controller = TimelineFeedController(source: fixture.source)
        let supervisor = Task { @MainActor in
            await controller.supervise()
        }

        await waitUntil { controller.timelineState.edges.map(\.id) == ["cached"] }
        controller.requestRefresh()
        await waitUntil {
            fixture.refreshCursors == [nil] && controller.timelineState.edges.map(\.id) == ["fresh"]
        }

        controller.cancelAll()
        await supervisor.value
    }

    @Test func disabledAutomaticInitialLoadStillAllowsExplicitRefresh() async {
        let fixture = TimelineFeedControllerFixture(
            initialResponses: [
                response(
                    [edge("explicit")],
                    hasNextPage: false,
                    startCursor: "explicit",
                    endCursor: "explicit"
                )
            ]
        )
        let controller = TimelineFeedController(source: fixture.source)
        let supervisor = Task { @MainActor in
            await controller.supervise(initialLoadEnabled: false)
        }

        await waitUntil { controller.hasActiveSupervisor }
        #expect(fixture.initialLoadCount == 0)
        #expect(controller.timelineState.edges.isEmpty)

        await controller.refresh()

        #expect(fixture.initialLoadCount == 1)
        #expect(controller.timelineState.edges.map(\.id) == ["explicit"])
        controller.cancelAll()
        await supervisor.value
    }

    private func edge(_ id: String) -> TimelineFeedControllerFixture.Edge {
        TimelineFeedControllerFixture.Edge(id: id, cursor: id)
    }

    private func response(
        _ edges: [TimelineFeedControllerFixture.Edge],
        hasPreviousPage: Bool = false,
        hasNextPage: Bool,
        startCursor: String?,
        endCursor: String?
    ) -> TimelineFeedResponse<TimelineFeedControllerFixture.Edge> {
        TimelineFeedResponse(
            connection: TimelineFeedConnection(
                edges: edges,
                pageInfo: TimelinePageInfo(
                    hasPreviousPage: hasPreviousPage,
                    hasNextPage: hasNextPage,
                    startCursor: startCursor,
                    endCursor: endCursor
                )
            ),
            errorMessages: []
        )
    }

    private func waitUntil(
        _ condition: @MainActor () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0 ..< 100 where !condition() {
            await Task.yield()
        }
        #expect(condition(), sourceLocation: sourceLocation)
    }
}

@MainActor
private final class TimelineFeedControllerFixture {
    struct Edge: Equatable {
        let id: String
        let cursor: String
    }

    var initialResponses: [TimelineFeedResponse<Edge>]
    var olderResponse: TimelineFeedResponse<Edge>?
    var newerResponse: TimelineFeedResponse<Edge>?
    var refreshResponse: TimelineFeedResponse<Edge>?
    private(set) var initialLoadCount = 0
    private(set) var olderCursors: [String] = []
    private(set) var newerCursors: [String] = []
    private(set) var refreshCursors: [String?] = []

    init(
        initialResponses: [TimelineFeedResponse<Edge>],
        olderResponse: TimelineFeedResponse<Edge>? = nil,
        newerResponse: TimelineFeedResponse<Edge>? = nil,
        refreshResponse: TimelineFeedResponse<Edge>? = nil
    ) {
        self.initialResponses = initialResponses
        self.olderResponse = olderResponse
        self.newerResponse = newerResponse
        self.refreshResponse = refreshResponse
    }

    var source: TimelineFeedSource<Edge> {
        TimelineFeedSource(
            fetchInitial: { receive in
                self.initialLoadCount += 1
                self.initialResponses.forEach(receive)
            },
            fetchRefreshPage: { cursor, _ in
                self.refreshCursors.append(cursor)
                return try self.response(self.refreshResponse)
            },
            fetchOlder: { cursor in
                self.olderCursors.append(cursor)
                return try self.response(self.olderResponse)
            },
            fetchNewer: { cursor in
                self.newerCursors.append(cursor)
                return try self.response(self.newerResponse)
            },
            identifier: \.id,
            cursor: \.cursor,
            identity: { PostListItemIdentity(rowID: $0.id, postID: $0.id, displayedPostID: nil) },
            errorFallback: "Timeline unavailable"
        )
    }

    private func response(_ response: TimelineFeedResponse<Edge>?) throws -> TimelineFeedResponse<Edge> {
        guard let response else { throw TimelineFeedControllerFixtureError.missingResponse }
        return response
    }
}

private enum TimelineFeedControllerFixtureError: LocalizedError {
    case missingResponse

    var errorDescription: String? {
        "Missing timeline fixture response"
    }
}
