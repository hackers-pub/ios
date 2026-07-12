@testable import HackersPub
import Testing

@MainActor
struct TimelineRefreshLimitsTests {
    private let warningMessage = "Refresh incomplete."

    @Test func productionDefaultsBoundPagesRowsAndConsecutiveNoProgress() {
        #expect(TimelineRefreshLimits.production.maxPages == 8)
        #expect(TimelineRefreshLimits.production.maxUniqueRows == 160)
        #expect(TimelineRefreshLimits.production.maxConsecutiveNoProgressPages == 2)
    }

    @Test func hugeTargetStopsAtThePageRequestBudgetAndPreservesExistingCursorState() async throws {
        var requestCount = 0
        let coordinator = coordinator(
            limits: limits(maxPages: 3, maxUniqueRows: 100, maxNoProgressPages: 2)
        ) { _, _ in
            requestCount += 1
            return page(
                [fixture("new-\(requestCount)")],
                hasNextPage: true,
                startCursor: "new-\(requestCount)",
                endCursor: "cursor-\(requestCount)"
            )
        }
        var state = loadedState([fixture("old-a"), fixture("old-b"), fixture("old-c"), fixture("old-d")])
        let pendingRequest = state.beginRefresh()
        let request = try #require(pendingRequest)

        let snapshot = try await coordinator.load(targetCount: 10000)

        #expect(requestCount == 3)
        #expect(snapshot.edges.map(\.id) == ["new-1", "new-2", "new-3"])
        #expect(snapshot.pageInfo.startCursor == "new-1")
        #expect(snapshot.pageInfo.endCursor == "cursor-3")
        #expect(snapshot.pageInfo.hasNextPage)
        #expect(snapshot.warning?.reason == .pageLimitReached)
        let applied = state.applyRefreshSnapshot(snapshot, identifier: \.id, for: request)
        #expect(applied)
        #expect(state.edges.map(\.id) == ["new-1", "new-2", "new-3", "old-a", "old-b", "old-c", "old-d"])
        #expect(state.startCursor == "old-a")
        #expect(state.endCursor == "old-d")
        #expect(state.hasNextPage)
    }

    @Test func advancingEmptyPagesStopAtTheNoProgressBudget() async throws {
        var requestCount = 0
        let coordinator = coordinator(
            limits: limits(maxPages: 10, maxUniqueRows: 100, maxNoProgressPages: 2)
        ) { _, _ in
            requestCount += 1
            return page(
                [],
                hasNextPage: true,
                startCursor: nil,
                endCursor: "empty-\(requestCount)"
            )
        }

        let snapshot = try await coordinator.load(targetCount: 10000)

        #expect(requestCount == 2)
        #expect(snapshot.edges.isEmpty)
        #expect(snapshot.pageInfo.endCursor == "empty-2")
        #expect(snapshot.pageInfo.hasNextPage)
        #expect(snapshot.warning?.reason == .noProgress)
        #expect(snapshot.warningMessage == warningMessage)
    }

    @Test func duplicateOnlyAdvancingPagesStopAfterConsecutiveNoProgress() async throws {
        var requestCount = 0
        let coordinator = coordinator(
            limits: limits(maxPages: 10, maxUniqueRows: 100, maxNoProgressPages: 2)
        ) { _, _ in
            requestCount += 1
            return page(
                [fixture("a")],
                hasNextPage: true,
                startCursor: "a",
                endCursor: "duplicate-\(requestCount)"
            )
        }

        let snapshot = try await coordinator.load(targetCount: 10000)

        #expect(requestCount == 3)
        #expect(snapshot.edges.map(\.id) == ["a"])
        #expect(snapshot.pageInfo.endCursor == "duplicate-3")
        #expect(snapshot.warning?.reason == .noProgress)
    }

    @Test func repeatedCursorStopsImmediatelyAsNonAuthoritativeNoProgress() async throws {
        var requestedCursors: [String?] = []
        let coordinator = coordinator(
            limits: limits(maxPages: 10, maxUniqueRows: 100, maxNoProgressPages: 2)
        ) { cursor, _ in
            requestedCursors.append(cursor)
            return page(
                [fixture(cursor == nil ? "a" : "b")],
                hasNextPage: true,
                startCursor: cursor == nil ? "a" : "b",
                endCursor: "repeat"
            )
        }

        let snapshot = try await coordinator.load(targetCount: 10000)

        #expect(requestedCursors == [nil, "repeat"])
        #expect(snapshot.edges.map(\.id) == ["a", "b"])
        #expect(snapshot.pageInfo.endCursor == "repeat")
        #expect(snapshot.pageInfo.hasNextPage)
        #expect(snapshot.warning?.reason == .noProgress)
    }

    @Test func oversizedNormalPageStopsAtTheUniqueRowBudgetWithoutDeletingExistingExtent() async throws {
        var requestCount = 0
        let coordinator = coordinator(
            limits: limits(maxPages: 10, maxUniqueRows: 10, maxNoProgressPages: 2)
        ) { _, _ in
            requestCount += 1
            return page(
                (0 ..< 100).map { fixture("new-\($0)") },
                hasNextPage: false,
                startCursor: "new-0",
                endCursor: "new-99"
            )
        }
        var state = loadedState([fixture("old-a"), fixture("old-b")])
        let pendingRequest = state.beginRefresh()
        let request = try #require(pendingRequest)

        let snapshot = try await coordinator.load(targetCount: 10000)

        #expect(requestCount == 1)
        #expect(snapshot.edges.count == 10)
        #expect(snapshot.edges.map(\.id) == (0 ..< 10).map { "new-\($0)" })
        #expect(snapshot.warning?.reason == .uniqueRowLimitReached)
        let applied = state.applyRefreshSnapshot(snapshot, identifier: \.id, for: request)
        #expect(applied)
        #expect(state.edges.suffix(2).map(\.id) == ["old-a", "old-b"])
        #expect(state.startCursor == "old-a")
        #expect(state.endCursor == "old-b")
    }

    @Test func refreshWithinEveryBudgetRemainsAuthoritative() async throws {
        var requestedCursors: [String?] = []
        let coordinator = coordinator(
            limits: limits(maxPages: 4, maxUniqueRows: 10, maxNoProgressPages: 2)
        ) { cursor, _ in
            requestedCursors.append(cursor)
            if cursor == nil {
                return page(
                    [fixture("a"), fixture("b")],
                    hasNextPage: true,
                    startCursor: "a",
                    endCursor: "cursor-2"
                )
            }
            return page(
                [fixture("c"), fixture("d")],
                hasNextPage: true,
                startCursor: "c",
                endCursor: "cursor-4"
            )
        }

        let snapshot = try await coordinator.load(targetCount: 4)

        #expect(requestedCursors == [nil, "cursor-2"])
        #expect(snapshot.edges.map(\.id) == ["a", "b", "c", "d"])
        #expect(snapshot.pageInfo.startCursor == "a")
        #expect(snapshot.pageInfo.endCursor == "cursor-4")
        #expect(snapshot.pageInfo.hasNextPage)
        #expect(snapshot.isAuthoritative)
        #expect(snapshot.warning == nil)
    }

    private func coordinator(
        limits: TimelineRefreshLimits,
        fetchPage: @escaping TimelineRefreshCoordinator<RefreshLimitFixture>.FetchPage
    ) -> TimelineRefreshCoordinator<RefreshLimitFixture> {
        TimelineRefreshCoordinator(
            pageSize: 20,
            identifier: \.id,
            limits: limits,
            partialFailureMessage: warningMessage,
            fetchPage: fetchPage
        )
    }

    private func limits(
        maxPages: Int,
        maxUniqueRows: Int,
        maxNoProgressPages: Int
    ) -> TimelineRefreshLimits {
        TimelineRefreshLimits(
            maxPages: maxPages,
            maxUniqueRows: maxUniqueRows,
            maxConsecutiveNoProgressPages: maxNoProgressPages
        )
    }

    private func loadedState(_ edges: [RefreshLimitFixture]) -> TimelineState<RefreshLimitFixture> {
        var state = TimelineState<RefreshLimitFixture>()
        guard let request = state.beginInitial() else { return state }
        _ = state.replaceFirstPage(
            edges,
            pageInfo: pageInfo(
                hasNextPage: true,
                startCursor: edges.first?.cursor,
                endCursor: edges.last?.cursor
            ),
            identifier: \.id,
            for: request
        )
        _ = state.finish(request, outcome: .success)
        return state
    }

    private func fixture(_ id: String) -> RefreshLimitFixture {
        RefreshLimitFixture(id: id, cursor: id)
    }

    private func page(
        _ edges: [RefreshLimitFixture],
        hasNextPage: Bool,
        startCursor: String?,
        endCursor: String?
    ) -> TimelineRefreshPage<RefreshLimitFixture> {
        TimelineRefreshPage(
            edges: edges,
            pageInfo: pageInfo(
                hasNextPage: hasNextPage,
                startCursor: startCursor,
                endCursor: endCursor
            ),
            warning: nil
        )
    }

    private func pageInfo(
        hasNextPage: Bool,
        startCursor: String?,
        endCursor: String?
    ) -> TimelinePageInfo {
        TimelinePageInfo(
            hasPreviousPage: false,
            hasNextPage: hasNextPage,
            startCursor: startCursor,
            endCursor: endCursor
        )
    }
}

private struct RefreshLimitFixture: Equatable {
    let id: String
    let cursor: String
}
