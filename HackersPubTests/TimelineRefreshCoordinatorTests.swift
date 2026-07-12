@testable import HackersPub
import Testing

@MainActor
struct TimelineRefreshCoordinatorTests {
    @Test func refreshesLoadedExtentAndKeepsCursorAlignedWithUnseenRows() async throws {
        var state = loadedState([
            fixture("a", cursor: "old-a"),
            fixture("b", cursor: "old-b"),
            fixture("c", cursor: "old-c"),
            fixture("d", cursor: "old-d")
        ])
        let refreshRequest = state.beginRefresh()
        let result = try await refreshedLoadedExtent(targetCount: state.edges.count)
        let snapshot = result.snapshot

        #expect(result.requestedCursors == [nil, "fresh-2"])
        #expect(snapshot.edges.map(\.id) == ["new", "a", "b", "c"])
        #expect(snapshot.pageInfo.endCursor == "fresh-4")
        #expect(snapshot.pageInfo.hasNextPage)

        let applied = refreshRequest.map {
            state.applyRefreshSnapshot(snapshot, identifier: \.id, for: $0)
        } ?? false
        #expect(applied)
        #expect(state.edges.map(\.id) == ["new", "a", "b", "c"])
        #expect(state.endCursor == "fresh-4")

        guard let refreshRequest else { return }
        _ = state.finish(refreshRequest, outcome: .success)
        let moreRequest = state.beginMore()
        #expect(moreRequest != nil)
        guard let moreRequest else { return }

        _ = state.appendPage(
            [
                fixture("d", cursor: "d"),
                fixture("e", cursor: "e")
            ],
            pageInfo: pageInfo(hasNextPage: false, startCursor: "d", endCursor: "e"),
            identifier: \.id,
            for: moreRequest
        )

        #expect(state.edges.map(\.id) == ["new", "a", "b", "c", "d", "e"])
    }

    @Test func authoritativeRefreshRemovesDeletedRows() async throws {
        let coordinator = TimelineRefreshCoordinator<RefreshFixture>(
            pageSize: 20,
            identifier: \.id
        ) { _, _ in
            refreshPage(
                [fixture("a"), fixture("c")],
                hasNextPage: false,
                startCursor: "a",
                endCursor: "c"
            )
        }
        var state = loadedState([fixture("a"), fixture("b"), fixture("c"), fixture("d")])
        let request = state.beginRefresh()
        let snapshot = try await coordinator.load(targetCount: state.edges.count)

        guard let request else { return }
        _ = state.applyRefreshSnapshot(snapshot, identifier: \.id, for: request)

        #expect(state.edges.map(\.id) == ["a", "c"])
        #expect(!state.hasNextPage)
        #expect(state.endCursor == "c")
    }

    @Test func authoritativeEmptyRefreshClearsLoadedRows() async throws {
        let coordinator = TimelineRefreshCoordinator<RefreshFixture>(
            pageSize: 20,
            identifier: \.id
        ) { _, _ in
            refreshPage([], hasNextPage: false, startCursor: nil, endCursor: nil)
        }
        var state = loadedState([fixture("a"), fixture("b")])
        let request = state.beginRefresh()
        let snapshot = try await coordinator.load(targetCount: state.edges.count)

        guard let request else { return }
        _ = state.applyRefreshSnapshot(snapshot, identifier: \.id, for: request)

        #expect(state.edges.isEmpty)
        #expect(state.endCursor == nil)
        #expect(!state.hasNextPage)
    }

    @Test func nonProgressingCursorReturnsPartialWithoutInventingPaginationCompletion() async throws {
        var callCount = 0
        let coordinator = TimelineRefreshCoordinator<RefreshFixture>(
            pageSize: 1,
            identifier: \.id
        ) { cursor, _ in
            callCount += 1
            return refreshPage(
                [fixture(cursor == nil ? "a" : "b")],
                hasNextPage: true,
                startCursor: cursor == nil ? "a" : "b",
                endCursor: "repeat"
            )
        }

        let snapshot = try await coordinator.load(targetCount: 10)

        #expect(callCount == 2)
        #expect(snapshot.edges.map(\.id) == ["a", "b"])
        #expect(snapshot.pageInfo.endCursor == "repeat")
        #expect(snapshot.pageInfo.hasNextPage)
        #expect(!snapshot.isAuthoritative)
        #expect(snapshot.warning?.reason == .noProgress)
    }

    @Test func cacheThenNetworkEmissionsApplyInArrivalOrder() {
        var state = TimelineState<RefreshFixture>()
        let request = state.beginInitial()
        guard let request else { return }

        let cache = TimelineRefreshSnapshot(
            edges: [fixture("cached", title: "cache")],
            pageInfo: pageInfo(hasNextPage: true, startCursor: "cached", endCursor: "cached"),
            completeness: .authoritative
        )
        let network = TimelineRefreshSnapshot(
            edges: [fixture("network", title: "network")],
            pageInfo: pageInfo(hasNextPage: false, startCursor: "network", endCursor: "network"),
            completeness: .authoritative
        )

        _ = state.applyRefreshSnapshot(cache, identifier: \.id, for: request)
        #expect(state.edges.map(\.id) == ["cached"])

        _ = state.applyRefreshSnapshot(network, identifier: \.id, for: request)
        #expect(state.edges.map(\.id) == ["network"])
        #expect(!state.hasNextPage)
    }

    @Test func staleAuthoritativeSnapshotCannotCommit() {
        var state = loadedState([fixture("current")])
        let staleRequest = state.beginRefresh()
        guard let staleRequest else { return }
        _ = state.finish(staleRequest, outcome: .cancelled)

        let currentRequest = state.beginRefresh()
        #expect(currentRequest != nil)
        let staleSnapshot = TimelineRefreshSnapshot(
            edges: [fixture("stale")],
            pageInfo: pageInfo(hasNextPage: false, startCursor: "stale", endCursor: "stale"),
            completeness: .authoritative
        )

        let applied = state.applyRefreshSnapshot(staleSnapshot, identifier: \.id, for: staleRequest)

        #expect(!applied)
        #expect(state.edges.map(\.id) == ["current"])
    }

    private func loadedState(_ edges: [RefreshFixture]) -> TimelineState<RefreshFixture> {
        var state = TimelineState<RefreshFixture>()
        let request = state.beginInitial()
        guard let request else { return state }

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

    private func refreshedLoadedExtent(
        targetCount: Int
    ) async throws -> (snapshot: TimelineRefreshSnapshot<RefreshFixture>, requestedCursors: [String?]) {
        var requestedCursors: [String?] = []
        let coordinator = TimelineRefreshCoordinator<RefreshFixture>(
            pageSize: 2,
            identifier: \.id
        ) { cursor, pageSize in
            requestedCursors.append(cursor)
            #expect(pageSize == 2)

            switch cursor {
            case nil:
                return refreshPage(
                    [fixture("new", cursor: "new"), fixture("a", cursor: "a")],
                    hasNextPage: true,
                    startCursor: "new",
                    endCursor: "fresh-2"
                )
            case "fresh-2":
                return refreshPage(
                    [fixture("b", cursor: "b"), fixture("c", cursor: "c")],
                    hasNextPage: true,
                    startCursor: "b",
                    endCursor: "fresh-4"
                )
            default:
                Issue.record("Unexpected cursor: \(String(describing: cursor))")
                return refreshPage([], hasNextPage: false, startCursor: nil, endCursor: nil)
            }
        }
        let snapshot = try await coordinator.load(targetCount: targetCount)
        return (snapshot, requestedCursors)
    }

    private func fixture(
        _ id: String,
        title: String? = nil,
        cursor: String? = nil
    ) -> RefreshFixture {
        RefreshFixture(id: id, title: title ?? id, cursor: cursor ?? id)
    }

    private func refreshPage(
        _ edges: [RefreshFixture],
        hasNextPage: Bool,
        startCursor: String?,
        endCursor: String?,
        warning: TimelineRefreshWarning? = nil
    ) -> TimelineRefreshPage<RefreshFixture> {
        TimelineRefreshPage(
            edges: edges,
            pageInfo: pageInfo(
                hasNextPage: hasNextPage,
                startCursor: startCursor,
                endCursor: endCursor
            ),
            warning: warning
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

private struct RefreshFixture: Equatable {
    let id: String
    let title: String
    let cursor: String
}
