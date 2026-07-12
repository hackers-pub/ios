import Foundation
@testable import HackersPub
import Testing

@Suite(.serialized)
@MainActor
struct QuotePaginationStateTests {
    @Test func deduplicatesQuotesWithinAndAcrossPagesInFirstServerOrder() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(
            request: 0,
            with: .success(page(["quote-a", "quote-a", "quote-b"], hasMore: true, endCursor: "cursor-1"))
        )
        await initial.value

        let more = Task { await state.loadMore() }
        await loader.waitForRequests(2)
        loader.complete(
            request: 1,
            with: .success(page(["quote-b", "quote-c", "quote-c"], hasMore: false, endCursor: nil))
        )
        await more.value

        #expect(state.items.map(\.id) == ["quote-a", "quote-b", "quote-c"])
        #expect(!state.hasMore)
    }

    @Test func stopsQuotePaginationWhenServerDoesNotAdvanceCursor() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(request: 0, with: .success(page(["quote-a"], hasMore: true, endCursor: "cursor-1")))
        await initial.value

        let more = Task { await state.loadMore() }
        await loader.waitForRequests(2)
        loader.complete(request: 1, with: .success(page(["quote-b"], hasMore: true, endCursor: "cursor-1")))
        await more.value

        await state.loadMore()

        #expect(state.items.map(\.id) == ["quote-a", "quote-b"])
        #expect(!state.hasMore)
        #expect(state.cursor == nil)
        #expect(loader.requestedCursors == [nil, "cursor-1"])
    }

    @Test func staleQuotePageCannotAppendOrOverwriteCursorAfterNewGeneration() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(request: 0, with: .success(page(["quote-old"], hasMore: true, endCursor: "cursor-old")))
        await initial.value

        let staleMore = Task { await state.loadMore() }
        await loader.waitForRequests(2)

        let replacement = Task { await state.reload() }
        await loader.waitForRequests(3)
        loader.complete(request: 2, with: .success(page(["quote-fresh"], hasMore: true, endCursor: "cursor-fresh")))
        await replacement.value

        loader.complete(request: 1, with: .success(page(["quote-stale"], hasMore: false, endCursor: nil)))
        await staleMore.value

        #expect(state.items.map(\.id) == ["quote-fresh"])
        #expect(state.cursor == "cursor-fresh")
        #expect(state.hasMore)
    }

    @Test func cancellingQuoteRequestPreventsLateResponseFromReplacingNewGeneration() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let staleInitial = Task { await state.reload() }
        await loader.waitForRequests(1)
        state.cancelPendingLoads()
        await loader.waitForCancellations(1)

        let replacement = Task { await state.reload() }
        await loader.waitForRequests(2)
        loader.complete(request: 1, with: .success(page(["quote-fresh"], hasMore: false, endCursor: nil)))
        await replacement.value

        loader.complete(request: 0, with: .success(page(["quote-stale"], hasMore: false, endCursor: nil)))
        await staleInitial.value

        #expect(state.items.map(\.id) == ["quote-fresh"])
        #expect(!state.isLoadingInitial)
        #expect(loader.cancelledCursors == [nil])
    }

    @Test func overlappingQuoteLoadMoreCallsUseOneRequestAndRetryPreservesRows() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(request: 0, with: .success(page(["quote-a"], hasMore: true, endCursor: "cursor-1")))
        await initial.value

        let firstMore = Task { await state.loadMore() }
        await loader.waitForRequests(2)
        let overlappingMore = Task { await state.loadMore() }
        await Task.yield()

        #expect(loader.requestedCursors == [nil, "cursor-1"])

        loader.complete(request: 1, with: .failure(.graphQL("quotes unavailable")))
        await firstMore.value
        await overlappingMore.value

        #expect(state.items.map(\.id) == ["quote-a"])
        #expect(state.paginationErrorMessage == "quotes unavailable")
        #expect(state.initialErrorMessage == nil)
        #expect(state.cursor == "cursor-1")

        let retry = Task { await state.retryLoadMore() }
        await loader.waitForRequests(3)
        loader.complete(request: 2, with: .success(page(["quote-b"], hasMore: false, endCursor: nil)))
        await retry.value

        #expect(state.items.map(\.id) == ["quote-a", "quote-b"])
        #expect(state.paginationErrorMessage == nil)
    }

    @Test func quoteInitialFailureIsSeparateFromPaginationFailure() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(request: 0, with: .failure(.graphQL("quotes unavailable")))
        await initial.value

        #expect(state.items.isEmpty)
        #expect(state.initialErrorMessage == "quotes unavailable")
        #expect(state.paginationErrorMessage == nil)
        #expect(state.showsInitialFailure)
    }

    @Test func quoteMissingDataDuringPaginationPreservesLoadedRows() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(request: 0, with: .success(page(["quote-a"], hasMore: true, endCursor: "cursor-1")))
        await initial.value

        let more = Task { await state.loadMore() }
        await loader.waitForRequests(2)
        loader.complete(request: 1, with: .failure(.missingData))
        await more.value

        #expect(state.items.map(\.id) == ["quote-a"])
        #expect(state.cursor == "cursor-1")
        #expect(state.paginationErrorMessage == PostEngagementSheetL10n.invalidResponse)
    }

    @Test func quoteSheetCallersUseTypedStateWithoutLegacyQuotePagination() throws {
        let postView = try engagementRepositorySource(at: "HackersPub/Views/PostView.swift")
        let postDetail = try engagementRepositorySource(at: "HackersPub/Views/PostDetailView.swift")

        for source in [postView, postDetail] {
            #expect(source.contains("EngagementListSheetState<PostEngagementSheetLoader.Quote>"))
            #expect(source.contains("state: quotesState"))
            #expect(!source.contains("private func loadMoreQuotes()"))
            #expect(!source.contains("quotesCursor"))
        }
    }
}

@Suite(.serialized)
@MainActor
struct SharePaginationStateTests {
    @Test func deduplicatesSharesWithinAndAcrossPagesInFirstServerOrder() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(
            request: 0,
            with: .success(page(["share-a", "share-a", "share-b"], hasMore: true, endCursor: "cursor-1"))
        )
        await initial.value

        let more = Task { await state.loadMore() }
        await loader.waitForRequests(2)
        loader.complete(
            request: 1,
            with: .success(page(["share-b", "share-c", "share-c"], hasMore: false, endCursor: nil))
        )
        await more.value

        #expect(state.items.map(\.id) == ["share-a", "share-b", "share-c"])
    }

    @Test func sharePaginationFailurePreservesRowsAndRetryUsesCurrentCursor() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(request: 0, with: .success(page(["share-a"], hasMore: true, endCursor: "cursor-1")))
        await initial.value

        let failedMore = Task { await state.loadMore() }
        await loader.waitForRequests(2)
        loader.complete(request: 1, with: .failure(.transport("offline")))
        await failedMore.value

        #expect(state.items.map(\.id) == ["share-a"])
        #expect(state.cursor == "cursor-1")
        #expect(state.hasMore)
        #expect(state.initialErrorMessage == nil)
        #expect(state.paginationErrorMessage == "offline")

        let retry = Task { await state.retryLoadMore() }
        await loader.waitForRequests(3)
        loader.complete(request: 2, with: .success(page(["share-b"], hasMore: false, endCursor: nil)))
        await retry.value

        #expect(loader.requestedCursors == [nil, "cursor-1", "cursor-1"])
        #expect(state.items.map(\.id) == ["share-a", "share-b"])
        #expect(state.paginationErrorMessage == nil)
    }

    @Test func cancelledSharePageCannotAppendOrOverwriteRetryCursor() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let initial = Task { await state.reload() }
        await loader.waitForRequests(1)
        loader.complete(request: 0, with: .success(page(["share-a"], hasMore: true, endCursor: "cursor-1")))
        await initial.value

        let staleMore = Task { await state.loadMore() }
        await loader.waitForRequests(2)
        state.cancelPendingLoads()
        await loader.waitForCancellations(1)

        let retry = Task { await state.retryLoadMore() }
        await loader.waitForRequests(3)
        loader.complete(request: 2, with: .success(page(["share-b"], hasMore: true, endCursor: "cursor-2")))
        await retry.value

        loader.complete(request: 1, with: .success(page(["share-stale"], hasMore: false, endCursor: nil)))
        await staleMore.value

        #expect(state.items.map(\.id) == ["share-a", "share-b"])
        #expect(state.cursor == "cursor-2")
        #expect(state.hasMore)
    }

    @Test func shareSheetCallersUseTypedStateWithoutLegacySharePagination() throws {
        let postView = try engagementRepositorySource(at: "HackersPub/Views/PostView.swift")
        let postDetail = try engagementRepositorySource(at: "HackersPub/Views/PostDetailView.swift")
        let sheets = try engagementRepositorySource(at: "HackersPub/Views/PostEngagementSheets.swift")

        for source in [postView, postDetail] {
            #expect(source.contains("EngagementListSheetState<ShareActorInfo>"))
            #expect(source.contains("state: sharesState"))
            #expect(!source.contains("private func loadMoreShares()"))
            #expect(!source.contains("sharesCursor"))
        }

        #expect(sheets.contains("presentation.paginationErrorMessage"))
        #expect(sheets.contains("EngagementPaginationErrorFooter"))
        #expect(sheets.contains("PostEngagementSheetL10n.paginationFailure"))
    }
}

@MainActor
final class ControlledEngagementPageLoader<Item> {
    private struct Request {
        let cursor: String?
        var continuation: CheckedContinuation<Result<EngagementListPage<Item>, EngagementListLoadFailure>, Never>?
    }

    private var requests: [Request] = []
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []
    private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []

    private(set) var cancelledCursors: [String?] = []

    var requestedCursors: [String?] {
        requests.map(\.cursor)
    }

    func load(after cursor: String?) async -> Result<EngagementListPage<Item>, EngagementListLoadFailure> {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                requests.append(Request(cursor: cursor, continuation: continuation))
                let waiters = requestWaiters
                requestWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume()
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                self?.recordCancellation(cursor)
            }
        }
    }

    func waitForRequests(_ count: Int) async {
        while requests.count < count {
            await withCheckedContinuation { continuation in
                requestWaiters.append(continuation)
            }
        }
    }

    func waitForCancellations(_ count: Int) async {
        while cancelledCursors.count < count {
            await withCheckedContinuation { continuation in
                cancellationWaiters.append(continuation)
            }
        }
    }

    func complete(
        request index: Int,
        with result: Result<EngagementListPage<Item>, EngagementListLoadFailure>
    ) {
        guard requests.indices.contains(index), let continuation = requests[index].continuation else {
            return
        }

        requests[index].continuation = nil
        continuation.resume(returning: result)
    }

    private func recordCancellation(_ cursor: String?) {
        cancelledCursors.append(cursor)
        let waiters = cancellationWaiters
        cancellationWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

struct TestEngagementItem: Identifiable, Equatable {
    let id: String
}

func page(
    _ ids: [String],
    hasMore: Bool,
    endCursor: String?
) -> EngagementListPage<TestEngagementItem> {
    EngagementListPage(
        items: ids.map(TestEngagementItem.init(id:)),
        hasMore: hasMore,
        endCursor: endCursor
    )
}

private func engagementRepositorySource(at relativePath: String) throws -> String {
    let repositoryURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: repositoryURL.appendingPathComponent(relativePath), encoding: .utf8)
}
