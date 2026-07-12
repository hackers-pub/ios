@testable import HackersPub
import Testing

@MainActor
struct NotificationFeedStateTests {
    @Test("SOC-1: a fresh request is independent from an active gap fill and coalesces one trailing latest request")
    func latestRequestsOutrankGapFillAndCoalesceExactlyOnce() throws {
        var state = NotificationFeedState<Fixture>(id: \.id)
        state.replaceInitial(with: page([fixture("old-a"), fixture("old-b")], end: "old-end", hasNext: true))

        let firstLatestRequest = state.beginLatestRequest()
        let firstLatest = try #require(firstLatestRequest)
        let firstCompletion = state.finishLatest(
            firstLatest,
            with: .success(page([fixture("fresh-a")], end: "fresh-end", hasNext: true))
        )
        #expect(firstCompletion == nil)
        let gapRequest = state.beginGapRequest()
        let gap = try #require(gapRequest)
        #expect(gap.cursor == "fresh-end")
        #expect(gap.direction == .after)

        let latestRequest = state.beginLatestRequest()
        let latest = try #require(latestRequest)
        let coalescedRequest = state.beginLatestRequest()
        #expect(coalescedRequest == nil) // exactly one trailing request is retained
        let trailingRequest = state.finishLatest(
            latest,
            with: .success(page([fixture("fresh-b")], end: "fresh-b-end", hasNext: true))
        )
        let trailing = try #require(trailingRequest)

        let acceptedStaleGap = state.finishGap(
            gap,
            with: .success(page([fixture("gap-stale")], end: "gap-end", hasNext: false))
        )
        #expect(!acceptedStaleGap)
        #expect(state.items.map(\.id) == ["fresh-b", "fresh-a", "old-a", "old-b"])

        let trailingCompletion = state.finishLatest(
            trailing,
            with: .success(page([fixture("fresh-c")], end: "fresh-c-end", hasNext: true))
        )
        #expect(trailingCompletion == nil)
        #expect(state.items.map(\.id).prefix(3) == ["fresh-c", "fresh-b", "fresh-a"])
        #expect(!state.isLatestLoading)
    }

    @Test("SOC-1: cancellation and errors release the latest slot while retaining exactly one coalesced retry")
    func latestCancellationAndErrorReleaseLoadingAndRemainRetryable() throws {
        var state = NotificationFeedState<Fixture>(id: \.id)
        state.replaceInitial(with: page([fixture("existing")], end: "end", hasNext: false))

        let cancelledRequest = state.beginLatestRequest()
        let cancelled = try #require(cancelledRequest)
        let coalescedRequest = state.beginLatestRequest()
        #expect(coalescedRequest == nil)
        let queuedRequest = state.finishLatest(cancelled, with: .cancelled)
        let queued = try #require(queuedRequest)
        #expect(state.isLatestLoading)
        #expect(state.errorMessage == nil)

        let failedCompletion = state.finishLatest(queued, with: .failure("offline"))
        #expect(failedCompletion == nil)
        #expect(!state.isLatestLoading)
        #expect(state.errorMessage == "offline")
        let retryRequest = state.beginLatestRequest()
        #expect(retryRequest != nil)
    }

    @Test("SOC-1: a failed gap fill releases its slot and preserves its cursor for retry")
    func failedGapFillIsRetryableWithoutBlockingLatestRequests() throws {
        var state = NotificationFeedState<Fixture>(id: \.id)
        state.replaceInitial(with: page([fixture("old")], end: "old-end", hasNext: true))
        let latestRequest = state.beginLatestRequest()
        let latest = try #require(latestRequest)
        _ = state.finishLatest(latest, with: .success(page([fixture("fresh")], end: "fresh-end", hasNext: true)))

        let gapRequest = state.beginGapRequest()
        let gap = try #require(gapRequest)
        let acceptedFailure = state.finishGap(gap, with: .failure("offline"))

        #expect(acceptedFailure)
        #expect(!state.isGapLoading)
        #expect(state.pendingGapCursor == "fresh-end")
        let retryGapRequest = state.beginGapRequest()
        #expect(retryGapRequest != nil)
        let concurrentLatestRequest = state.beginLatestRequest()
        #expect(concurrentLatestRequest != nil)
    }

    @Test("SOC-1: an authoritative latest request invalidates older work that was already in flight")
    func latestRequestInvalidatesPreviouslyStartedOlderWork() throws {
        var state = NotificationFeedState<Fixture>(id: \.id)
        state.replaceInitial(with: page([fixture("old-a"), fixture("old-b")], end: "old-end", hasNext: true))

        let olderRequestValue = state.beginOlderRequest()
        let olderRequest = try #require(olderRequestValue)
        #expect(state.isOlderLoading)

        let latestRequestValue = state.beginLatestRequest()
        let latestRequest = try #require(latestRequestValue)
        #expect(!state.isOlderLoading)
        _ = state.finishLatest(
            latestRequest,
            with: .success(page([fixture("fresh")], end: "fresh-end", hasNext: false))
        )

        let expectedItems = state.items
        let expectedEndCursor = state.endCursor
        let expectedError = state.errorMessage

        let acceptedSuccess = state.finishOlder(
            olderRequest,
            with: .success(page([fixture("stale-success")], end: "stale-end", hasNext: true))
        )
        let acceptedFailure = state.finishOlder(olderRequest, with: .failure("stale-error"))
        let acceptedCancellation = state.finishOlder(olderRequest, with: .cancelled)
        #expect(!acceptedSuccess)
        #expect(!acceptedFailure)
        #expect(!acceptedCancellation)
        #expect(state.items == expectedItems)
        #expect(state.endCursor == expectedEndCursor)
        #expect(state.errorMessage == expectedError)
        #expect(!state.isOlderLoading)
        #expect(!state.hasNextPage)
    }

    @Test("SOC-1: committing an authoritative latest page invalidates older work started during it")
    func latestCommitInvalidatesNewerOverlappingOlderWork() throws {
        var state = NotificationFeedState<Fixture>(id: \.id)
        state.replaceInitial(with: page([fixture("old")], end: "old-end", hasNext: true))

        let latestRequestValue = state.beginLatestRequest()
        let latestRequest = try #require(latestRequestValue)
        let olderRequestValue = state.beginOlderRequest()
        let olderRequest = try #require(olderRequestValue)
        #expect(state.isOlderLoading)

        _ = state.finishLatest(
            latestRequest,
            with: .success(page([fixture("fresh")], end: "fresh-end", hasNext: false))
        )

        #expect(!state.isOlderLoading)
        let acceptedFailure = state.finishOlder(olderRequest, with: .failure("late older failure"))
        #expect(!acceptedFailure)
        #expect(state.items.map(\.id) == ["fresh"])
        #expect(state.endCursor == "fresh-end")
        #expect(state.errorMessage == nil)
    }

    @Test("SOC-3: both gap completion and older pagination use reachable forward cursors")
    func reachableForwardPaginationUsesCorrectCursorDirection() throws {
        var state = NotificationFeedState<Fixture>(id: \.id)
        state.replaceInitial(with: page([fixture("old-a")], end: "old-end", hasNext: true))

        let latestRequest = state.beginLatestRequest()
        let latest = try #require(latestRequest)
        _ = state.finishLatest(latest, with: .success(page([fixture("fresh-a")], end: "fresh-end", hasNext: true)))

        let gapRequest = state.beginGapRequest()
        let gap = try #require(gapRequest)
        #expect(gap.kind == .gap)
        #expect(gap.direction == .after)
        #expect(gap.cursor == "fresh-end")

        _ = state.finishGap(gap, with: .success(page([fixture("between")], end: "between-end", hasNext: false)))
        let olderRequest = state.beginOlderRequest()
        let older = try #require(olderRequest)
        #expect(older.kind == .older)
        #expect(older.direction == .after)
        #expect(older.cursor == "old-end")
    }

    @Test("SOC-4: non-first aggregate overlap upserts every fresh item in server order")
    func stableIdentityUpsertDoesNotDropItemsAfterAReorderedAggregate() throws {
        var state = NotificationFeedState<Fixture>(id: \.id)
        state.replaceInitial(
            with: page(
                [fixture("aggregate", "old"), fixture("older-a"), fixture("older-b")],
                end: "old-end",
                hasNext: true
            )
        )

        let latestRequest = state.beginLatestRequest()
        let latest = try #require(latestRequest)
        _ = state.finishLatest(
            latest,
            with: .success(
                page(
                    [fixture("new-a"), fixture("aggregate", "updated"), fixture("new-b")],
                    end: "fresh-end",
                    hasNext: true
                )
            )
        )

        #expect(state.items.map(\.id) == ["new-a", "aggregate", "new-b", "older-a", "older-b"])
        let aggregate = state.items.first { $0.id == "aggregate" }
        #expect(aggregate?.payload == "updated")
        #expect(state.pendingGapCursor == "fresh-end")
    }

    @Test("SOC-4: repeated pages and non-progressing cursors close the gap without duplicate identities")
    func repeatedGapPageCannotLoopOrDuplicateRows() throws {
        var state = NotificationFeedState<Fixture>(id: \.id)
        state.replaceInitial(with: page([fixture("old")], end: "old-end", hasNext: true))
        let latestRequest = state.beginLatestRequest()
        let latest = try #require(latestRequest)
        _ = state.finishLatest(latest, with: .success(page([fixture("fresh")], end: "fresh-end", hasNext: true)))
        let gapRequest = state.beginGapRequest()
        let gap = try #require(gapRequest)

        let acceptedGap = state.finishGap(
            gap,
            with: .success(
                page([fixture("fresh"), fixture("between"), fixture("between")], end: "fresh-end", hasNext: true)
            )
        )
        #expect(acceptedGap)
        #expect(state.items.map(\.id) == ["fresh", "between", "old"])
        #expect(state.pendingGapCursor == nil)
        #expect(state.beginGapRequest() == nil)
    }

    private struct Fixture: Equatable {
        let id: String
        let payload: String
    }

    private func fixture(_ id: String, _ payload: String? = nil) -> Fixture {
        Fixture(id: id, payload: payload ?? id)
    }

    private func page(
        _ items: [Fixture],
        end: String?,
        hasNext: Bool,
        start: String? = nil
    ) -> NotificationFeedPage<Fixture> {
        NotificationFeedPage(
            items: items,
            startCursor: start,
            endCursor: end,
            hasNextPage: hasNext
        )
    }
}
