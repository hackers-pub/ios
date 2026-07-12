import Foundation
@testable import HackersPub
import Testing

@MainActor
struct ArticleDraftPaginationTests {
    @Test func appendsSecondPageAfterFiftyInitialDrafts() {
        var state = ArticleDraftPaginationState<Draft>(nodeID: \.id)
        state.replace(
            with: page(
                (0 ..< 50).map { draft("draft-\($0)") },
                hasNextPage: true,
                endCursor: "cursor-50"
            )
        )

        #expect(state.beginLoadingMore() == "cursor-50")
        state.append(
            page(
                [draft("draft-50")],
                hasNextPage: false,
                endCursor: "cursor-51"
            )
        )

        #expect(state.items.map(\.id) == (0 ... 50).map { "draft-\($0)" })
        #expect(!state.hasNextPage)
        #expect(!state.isLoadingMore)
    }

    @Test func deduplicatesBoundaryDraftByNodeIDWhilePreservingOrder() {
        var state = ArticleDraftPaginationState<Draft>(nodeID: \.id)
        state.replace(
            with: page(
                [draft("draft-0"), draft("draft-1")],
                hasNextPage: true,
                endCursor: "cursor-2"
            )
        )

        #expect(state.beginLoadingMore() == "cursor-2")
        state.append(
            page(
                [draft("draft-1"), draft("draft-2"), draft("draft-2")],
                hasNextPage: false,
                endCursor: "cursor-3"
            )
        )

        #expect(state.items.map(\.id) == ["draft-0", "draft-1", "draft-2"])
    }

    @Test func doesNotRequestAnotherPageWhenThereIsNoNextPage() {
        var state = ArticleDraftPaginationState<Draft>(nodeID: \.id)
        state.replace(
            with: page(
                [draft("draft-0")],
                hasNextPage: false,
                endCursor: "cursor-1"
            )
        )

        #expect(state.beginLoadingMore() == nil)
        #expect(!state.isLoadingMore)
    }

    @Test func loadMoreFailurePreservesFirstPageCursorAndRetry() {
        var state = ArticleDraftPaginationState<Draft>(nodeID: \.id)
        let firstPage = (0 ..< 50).map { draft("draft-\($0)") }
        state.replace(
            with: page(
                firstPage,
                hasNextPage: true,
                endCursor: "cursor-50"
            )
        )

        #expect(state.beginLoadingMore() == "cursor-50")
        state.recordLoadMoreFailure("second page failed")

        #expect(state.items == firstPage)
        #expect(state.endCursor == "cursor-50")
        #expect(state.hasNextPage)
        #expect(!state.isLoadingMore)
        #expect(state.loadMoreErrorMessage == "second page failed")
        #expect(state.beginLoadingMore() == "cursor-50")
        #expect(state.loadMoreErrorMessage == nil)
    }

    @Test func viewStateRefreshSupersedesAnInFlightOlderPage() async {
        let pageLoader = ControlledArticleDraftPageLoader<Draft>()
        let loader = ArticleDraftListLoader(nodeID: \Draft.id, pageLoader: pageLoader.load)

        let initialRefresh = Task { @MainActor in
            await loader.refresh()
        }
        await pageLoader.waitForRequestCount(1)
        #expect(pageLoader.requestedCursors == [nil])
        pageLoader.succeed(
            request: 0,
            with: page(
                [draft("old-a")],
                hasNextPage: true,
                endCursor: "old-cursor"
            )
        )
        await initialRefresh.value

        let staleLoadMore = Task { @MainActor in
            await loader.loadMore()
        }
        await pageLoader.waitForRequestCount(2)
        #expect(pageLoader.requestedCursors[1] == "old-cursor")

        let latestRefresh = Task { @MainActor in
            await loader.refresh()
        }
        await pageLoader.waitForRequestCount(3)
        #expect(pageLoader.requestedCursors[2] == nil)
        pageLoader.succeed(
            request: 2,
            with: page(
                [draft("new-a"), draft("new-a")],
                hasNextPage: true,
                endCursor: "new-cursor"
            )
        )
        await latestRefresh.value

        pageLoader.succeed(
            request: 1,
            with: page(
                [draft("old-b")],
                hasNextPage: false,
                endCursor: nil
            )
        )
        await staleLoadMore.value

        assertCurrentPageState(loader)
    }

    @Test func viewStateTreatsPageCancellationAsSilentAndPreservesRows() async {
        let pageLoader = ControlledArticleDraftPageLoader<Draft>()
        let loader = ArticleDraftListLoader(nodeID: \Draft.id, pageLoader: pageLoader.load)
        await installFirstPage(
            on: loader,
            pageLoader: pageLoader,
            page: page(
                [draft("draft-a")],
                hasNextPage: true,
                endCursor: "next"
            )
        )

        let loadMore = Task { @MainActor in
            await loader.loadMore()
        }
        await pageLoader.waitForRequestCount(2)
        pageLoader.fail(request: 1, with: CancellationError())
        await loadMore.value

        #expect(loader.items.map(\.id) == ["draft-a"])
        #expect(loader.endCursor == "next")
        #expect(loader.errorMessage == nil)
        #expect(loader.loadMoreErrorMessage == nil)
        #expect(!loader.isLoadingMore)
    }

    @Test func viewStatePreservesRowsAfterPageErrorAndRetriesTheSameCursor() async {
        let pageLoader = ControlledArticleDraftPageLoader<Draft>()
        let loader = ArticleDraftListLoader(nodeID: \Draft.id, pageLoader: pageLoader.load)
        await installFirstPage(
            on: loader,
            pageLoader: pageLoader,
            page: page(
                [draft("draft-a")],
                hasNextPage: true,
                endCursor: "next"
            )
        )

        let failingLoadMore = Task { @MainActor in
            await loader.loadMore()
        }
        await pageLoader.waitForRequestCount(2)
        pageLoader.fail(request: 1, with: DraftPageError.failed)
        await failingLoadMore.value

        #expect(loader.items.map(\.id) == ["draft-a"])
        #expect(loader.endCursor == "next")
        #expect(loader.loadMoreErrorMessage == DraftPageError.failed.localizedDescription)

        let retry = Task { @MainActor in
            await loader.loadMore()
        }
        await pageLoader.waitForRequestCount(3)
        #expect(pageLoader.requestedCursors[2] == "next")
        pageLoader.succeed(
            request: 2,
            with: page(
                [draft("draft-a"), draft("draft-b"), draft("draft-b")],
                hasNextPage: false,
                endCursor: nil
            )
        )
        await retry.value

        #expect(loader.items.map(\.id) == ["draft-a", "draft-b"])
        #expect(!loader.hasNextPage)
        #expect(loader.loadMoreErrorMessage == nil)
    }

    private struct Draft: Identifiable, Equatable {
        let id: String
    }

    private func draft(_ id: String) -> Draft {
        Draft(id: id)
    }

    private func page(_ items: [Draft], hasNextPage: Bool, endCursor: String?) -> ArticleDraftPage<Draft> {
        ArticleDraftPage(
            items: items,
            hasNextPage: hasNextPage,
            endCursor: endCursor
        )
    }

    private func installFirstPage(
        on loader: ArticleDraftListLoader<Draft>,
        pageLoader: ControlledArticleDraftPageLoader<Draft>,
        page: ArticleDraftPage<Draft>
    ) async {
        let refresh = Task { @MainActor in
            await loader.refresh()
        }
        await pageLoader.waitForRequestCount(1)
        pageLoader.succeed(request: 0, with: page)
        await refresh.value
    }

    private func assertCurrentPageState(_ loader: ArticleDraftListLoader<Draft>) {
        #expect(loader.items.map(\.id) == ["new-a"])
        #expect(loader.hasNextPage)
        #expect(loader.endCursor == "new-cursor")
        #expect(!loader.isLoading)
        #expect(!loader.isLoadingMore)
        #expect(loader.errorMessage == nil)
        #expect(loader.loadMoreErrorMessage == nil)
    }
}

private enum DraftPageError: LocalizedError {
    case failed

    var errorDescription: String? {
        "page failed"
    }
}

@MainActor
private final class ControlledArticleDraftPageLoader<Item> {
    private var continuations: [CheckedContinuation<ArticleDraftPage<Item>, any Error>] = []
    private(set) var requestedCursors: [String?] = []

    func load(after cursor: String?) async throws -> ArticleDraftPage<Item> {
        requestedCursors.append(cursor)
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForRequestCount(_ count: Int) async {
        while requestedCursors.count < count {
            await Task.yield()
        }
    }

    func succeed(request: Int, with page: ArticleDraftPage<Item>) {
        continuations[request].resume(returning: page)
    }

    func fail(request: Int, with error: any Error) {
        continuations[request].resume(throwing: error)
    }
}
