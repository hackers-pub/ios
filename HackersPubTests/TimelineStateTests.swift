@testable import HackersPub
import Testing

// swiftlint:disable:next type_body_length
struct TimelineStateTests {
    @Test func cancellingInitialRequestReleasesLoadingAndReopensInitialGate() {
        var state = TimelineState<TimelineFixture>()
        let request = state.beginInitial()

        #expect(request != nil)
        #expect(state.isInitialLoading)
        #expect(!state.hasLoadedInitial)

        guard let request else { return }
        _ = state.finish(request, outcome: .cancelled)

        #expect(!state.isInitialLoading)
        #expect(state.shouldLoadInitial)
        #expect(state.errorMessage == nil)
    }

    @Test func staleRequestCannotApplyOrFinishOverNewerGeneration() {
        var state = TimelineState<TimelineFixture>()
        let staleRequest = state.beginInitial()
        #expect(staleRequest != nil)

        guard let staleRequest else { return }
        _ = state.finish(staleRequest, outcome: .cancelled)

        let currentRequest = state.beginInitial()
        #expect(currentRequest != nil)
        guard let currentRequest else { return }

        let staleApplied = state.replaceFirstPage(
            [TimelineFixture(id: "stale", title: "stale", cursor: "stale")],
            pageInfo: pageInfo(),
            identifier: \.id,
            for: staleRequest
        )
        let staleFinished = state.finish(staleRequest, outcome: .success)

        #expect(!staleApplied)
        #expect(!staleFinished)
        #expect(state.isCurrent(currentRequest))
        #expect(state.isInitialLoading)
        #expect(state.edges.isEmpty)
    }

    @Test func newerAndOlderLoadingStatesRemainIndependent() {
        var state = TimelineState<TimelineFixture>()
        let initialRequest = state.beginInitial()
        #expect(initialRequest != nil)
        guard let initialRequest else { return }

        _ = state.replaceFirstPage(
            [TimelineFixture(id: "a", title: "A", cursor: "a")],
            pageInfo: pageInfo(hasNextPage: true),
            identifier: \.id,
            for: initialRequest
        )
        _ = state.finish(initialRequest, outcome: .success)

        let newerRequest = state.beginNewer()
        #expect(newerRequest == nil)

        let newerSetupRequest = state.beginRefresh()
        #expect(newerSetupRequest != nil)
        guard let newerSetupRequest else { return }

        _ = state.mergeNewerPage(
            [TimelineFixture(id: "new", title: "New", cursor: "new")],
            page: TimelineNewerPage(
                nextCursor: "newer-page",
                hasMoreNewer: true,
                fallbackEndCursor: "a"
            ),
            cursor: \.cursor,
            identifier: \.id,
            for: newerSetupRequest
        )
        _ = state.finish(newerSetupRequest, outcome: .success)

        let newerLoadingRequest = state.beginNewer()
        #expect(newerLoadingRequest != nil)
        #expect(state.isLoadingNewer)
        #expect(!state.isLoadingMore)

        guard let newerLoadingRequest else { return }
        _ = state.finish(newerLoadingRequest, outcome: .success)

        let olderLoadingRequest = state.beginMore()
        #expect(olderLoadingRequest != nil)
        #expect(!state.isLoadingNewer)
        #expect(state.isLoadingMore)
    }

    @Test func prependingMovesRebroadcastToNewestPositionWithoutCollapsingDistinctWrappers() {
        let existing = [
            TimelineFixture(id: "boost-1", title: "old boost", cursor: "old-boost"),
            TimelineFixture(id: "quote-1", title: "quote", cursor: "quote")
        ]
        let incoming = [
            TimelineFixture(id: "boost-1", title: "updated boost", cursor: "new-boost"),
            TimelineFixture(id: "boost-2", title: "second boost", cursor: "second-boost")
        ]

        let merged = TimelineMergePolicy.prepending(incoming, to: existing, identifier: \.id)

        #expect(merged.map(\.id) == ["boost-1", "boost-2", "quote-1"])
        #expect(merged.first?.title == "updated boost")
    }

    @Test func refreshingUsesFreshServerOrderForAnExistingRebroadcast() {
        let existing = [
            TimelineFixture(id: "quote-1", title: "quote", cursor: "quote"),
            TimelineFixture(id: "boost-1", title: "old boost", cursor: "old-boost")
        ]
        let incoming = [
            TimelineFixture(id: "boost-1", title: "fresh boost", cursor: "fresh-boost"),
            TimelineFixture(id: "wrapper-2", title: "wrapper", cursor: "wrapper")
        ]

        let merged = TimelineMergePolicy.refreshing(incoming, to: existing, identifier: \.id)

        #expect(merged.map(\.id) == ["boost-1", "wrapper-2", "quote-1"])
        #expect(merged.first?.title == "fresh boost")
    }

    @Test func refreshUpdatesExistingSnapshotsPrependsNewItemsAndUsesFreshPageInfo() {
        var state = TimelineState<TimelineFixture>()
        let initialRequest = state.beginInitial()
        #expect(initialRequest != nil)
        guard let initialRequest else { return }

        _ = state.replaceFirstPage(
            [
                TimelineFixture(id: "a", title: "old A", cursor: "a"),
                TimelineFixture(id: "b", title: "old B", cursor: "b")
            ],
            pageInfo: pageInfo(hasNextPage: true, startCursor: "a", endCursor: "b"),
            identifier: \.id,
            for: initialRequest
        )
        _ = state.finish(initialRequest, outcome: .success)

        let refreshRequest = state.beginRefresh()
        #expect(refreshRequest != nil)
        guard let refreshRequest else { return }

        let applied = state.mergeRefreshFirstPage(
            [
                TimelineFixture(id: "new", title: "new", cursor: "new"),
                TimelineFixture(id: "a", title: "fresh A", cursor: "fresh-a")
            ],
            pageInfo: pageInfo(hasNextPage: true, startCursor: "new", endCursor: "fresh-a"),
            identifier: \.id,
            for: refreshRequest
        )

        #expect(applied)
        #expect(state.edges.map(\.id) == ["new", "a", "b"])
        #expect(state.edges.dropFirst().first?.title == "fresh A")
        #expect(state.startCursor == "new")
        #expect(state.endCursor == "fresh-a")
        #expect(state.hasNextPage)
    }

    @Test func appendingSkipsAnAlreadyLoadedSemanticIdentityWithoutReorderingIt() {
        var state = TimelineState<TimelineFixture>()
        let initialRequest = state.beginInitial()
        #expect(initialRequest != nil)
        guard let initialRequest else { return }

        _ = state.replaceFirstPage(
            [
                TimelineFixture(id: "a", title: "original A", cursor: "a"),
                TimelineFixture(id: "b", title: "B", cursor: "b")
            ],
            pageInfo: pageInfo(hasNextPage: true, startCursor: "a", endCursor: "b"),
            identifier: \.id,
            for: initialRequest
        )
        _ = state.finish(initialRequest, outcome: .success)

        let moreRequest = state.beginMore()
        #expect(moreRequest != nil)
        guard let moreRequest else { return }

        let applied = state.appendPage(
            [
                TimelineFixture(id: "a", title: "duplicate A", cursor: "new-a"),
                TimelineFixture(id: "c", title: "C", cursor: "c")
            ],
            pageInfo: pageInfo(hasNextPage: false, startCursor: "new-a", endCursor: "c"),
            identifier: \.id,
            for: moreRequest
        )

        #expect(applied)
        #expect(state.edges.map(\.id) == ["a", "b", "c"])
        #expect(state.edges.first?.title == "original A")
    }

    @Test func inPlaceAppendingMatchesThePureMergePolicyForDuplicatePrefixes() {
        let existing = [
            TimelineFixture(id: "a", title: "first A", cursor: "a"),
            TimelineFixture(id: "a", title: "duplicate A", cursor: "duplicate-a"),
            TimelineFixture(id: "b", title: "B", cursor: "b")
        ]
        let incoming = [
            TimelineFixture(id: "b", title: "duplicate B", cursor: "duplicate-b"),
            TimelineFixture(id: "c", title: "C", cursor: "c"),
            TimelineFixture(id: "c", title: "duplicate C", cursor: "duplicate-c")
        ]
        let expected = TimelineMergePolicy.appending(incoming, to: existing, identifier: \.id)
        var merged = existing

        TimelineMergePolicy.append(incoming, to: &merged, identifier: \.id)

        #expect(merged == expected)
    }

    @Test func partialNetworkEmissionMergesIntoCachedItemsWithoutDestroyingThem() {
        var state = TimelineState<TimelineFixture>()
        let request = state.beginInitial()
        #expect(request != nil)
        guard let request else { return }

        _ = state.replaceFirstPage(
            [
                TimelineFixture(id: "cached", title: "cached", cursor: "cached"),
                TimelineFixture(id: "preserved", title: "preserved", cursor: "preserved")
            ],
            pageInfo: pageInfo(hasNextPage: true, startCursor: "cached", endCursor: "preserved"),
            identifier: \.id,
            for: request
        )

        let applied = state.mergeRefreshFirstPage(
            [TimelineFixture(id: "cached", title: "network update", cursor: "network-cached")],
            pageInfo: pageInfo(hasNextPage: true, startCursor: "network-cached", endCursor: "network-cached"),
            identifier: \.id,
            for: request
        )
        _ = state.finish(request, outcome: .partialSuccess("field unavailable"))

        #expect(applied)
        #expect(state.edges.map(\.id) == ["cached", "preserved"])
        #expect(state.edges.first?.title == "network update")
        #expect(state.errorMessage == "field unavailable")
    }

    @Test func partialGraphQLErrorWithUsableDataIsNonDestructive() {
        let disposition = TimelineResponsePolicy.disposition(
            hasConnection: true,
            incomingCount: 1,
            hasExistingContent: true,
            graphQLErrorMessages: ["field unavailable"],
            fallbackMessage: "Timeline unavailable"
        )

        #expect(disposition == .usableWithWarning("field unavailable"))
    }

    @Test func successfulEmptyConnectionRemainsAnExplicitEmptyState() {
        let disposition = TimelineResponsePolicy.disposition(
            hasConnection: true,
            incomingCount: 0,
            hasExistingContent: false,
            graphQLErrorMessages: [],
            fallbackMessage: "Timeline unavailable"
        )

        #expect(disposition == .usable)
    }

    @Test func successfulEmptyInitialPageCompletesWithoutAnError() {
        var state = TimelineState<TimelineFixture>()
        let request = state.beginInitial()
        #expect(request != nil)
        guard let request else { return }

        _ = state.replaceFirstPage(
            [],
            pageInfo: pageInfo(hasNextPage: false, startCursor: nil, endCursor: nil),
            identifier: \.id,
            for: request
        )
        _ = state.finish(request, outcome: .success)

        #expect(state.hasLoadedInitial)
        #expect(state.edges.isEmpty)
        #expect(state.errorMessage == nil)
        #expect(!state.isInitialLoading)
    }

    @Test func graphQLErrorWithoutUsableDataIsVisibleFailure() {
        let disposition = TimelineResponsePolicy.disposition(
            hasConnection: false,
            incomingCount: 0,
            hasExistingContent: false,
            graphQLErrorMessages: ["timeline unavailable"],
            fallbackMessage: "Timeline unavailable"
        )

        #expect(disposition == .failure("timeline unavailable"))
    }

    private func pageInfo(
        hasNextPage: Bool = false,
        startCursor: String? = "start",
        endCursor: String? = "end"
    ) -> TimelinePageInfo {
        TimelinePageInfo(
            hasPreviousPage: false,
            hasNextPage: hasNextPage,
            startCursor: startCursor,
            endCursor: endCursor
        )
    }
}

private struct TimelineFixture: Equatable {
    let id: String
    let title: String
    let cursor: String
}
