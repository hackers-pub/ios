@testable import HackersPub
import Testing

@MainActor
extension QuotePaginationStateTests {
    @Test func quotePostIDResetCommitsOnlyNewLoaderState() async {
        let oldLoader = ControlledEngagementPageLoader<TestEngagementItem>()
        let newLoader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await oldLoader.load(after: cursor)
        }

        let oldPostLoad = Task { await state.reload() }
        await oldLoader.waitForRequests(1)

        state.reset { cursor in
            await newLoader.load(after: cursor)
        }
        await oldLoader.waitForCancellations(1)

        let newPostLoad = Task { await state.reload() }
        await newLoader.waitForRequests(1)
        newLoader.complete(request: 0, with: .failure(.graphQL("new quote error")))
        await newPostLoad.value

        oldLoader.complete(
            request: 0,
            with: .success(page(["quote-stale"], hasMore: true, endCursor: "quote-stale-cursor"))
        )
        await oldPostLoad.value

        #expect(state.items.isEmpty)
        #expect(state.initialErrorMessage == "new quote error")
        #expect(state.paginationErrorMessage == nil)
        #expect(state.cursor == nil)
        #expect(!state.hasMore)

        let retry = Task { await state.retryInitial() }
        await newLoader.waitForRequests(2)
        newLoader.complete(
            request: 1,
            with: .success(page(["quote-fresh"], hasMore: true, endCursor: "quote-fresh-cursor"))
        )
        await retry.value

        #expect(newLoader.requestedCursors == [nil, nil])
        #expect(state.items.map(\.id) == ["quote-fresh"])
        #expect(state.initialErrorMessage == nil)
        #expect(state.cursor == "quote-fresh-cursor")
        #expect(state.hasMore)
    }

    @Test func quoteSheetReopenInvalidatesPreviousInFlightGeneration() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let firstOpen = Task { await state.reload() }
        await loader.waitForRequests(1)

        let reopened = Task { await state.reload() }
        await loader.waitForRequests(2)
        await loader.waitForCancellations(1)
        loader.complete(
            request: 1,
            with: .success(page(["quote-reopened"], hasMore: true, endCursor: "quote-reopened-cursor"))
        )
        await reopened.value

        loader.complete(request: 0, with: .failure(.graphQL("stale quote error")))
        await firstOpen.value

        #expect(state.items.map(\.id) == ["quote-reopened"])
        #expect(state.initialErrorMessage == nil)
        #expect(state.paginationErrorMessage == nil)
        #expect(state.cursor == "quote-reopened-cursor")
        #expect(state.hasMore)
    }
}

@MainActor
extension SharePaginationStateTests {
    @Test func sharePostIDResetCommitsOnlyNewLoaderState() async {
        let oldLoader = ControlledEngagementPageLoader<TestEngagementItem>()
        let newLoader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await oldLoader.load(after: cursor)
        }

        let oldPostLoad = Task { await state.reload() }
        await oldLoader.waitForRequests(1)

        state.reset { cursor in
            await newLoader.load(after: cursor)
        }
        await oldLoader.waitForCancellations(1)

        let newPostLoad = Task { await state.reload() }
        await newLoader.waitForRequests(1)
        newLoader.complete(request: 0, with: .failure(.graphQL("new share error")))
        await newPostLoad.value

        oldLoader.complete(
            request: 0,
            with: .success(page(["share-stale"], hasMore: true, endCursor: "share-stale-cursor"))
        )
        await oldPostLoad.value

        #expect(state.items.isEmpty)
        #expect(state.initialErrorMessage == "new share error")
        #expect(state.paginationErrorMessage == nil)
        #expect(state.cursor == nil)
        #expect(!state.hasMore)

        let retry = Task { await state.retryInitial() }
        await newLoader.waitForRequests(2)
        newLoader.complete(
            request: 1,
            with: .success(page(["share-fresh"], hasMore: true, endCursor: "share-fresh-cursor"))
        )
        await retry.value

        #expect(newLoader.requestedCursors == [nil, nil])
        #expect(state.items.map(\.id) == ["share-fresh"])
        #expect(state.initialErrorMessage == nil)
        #expect(state.cursor == "share-fresh-cursor")
        #expect(state.hasMore)
    }

    @Test func shareSheetReopenInvalidatesPreviousInFlightGeneration() async {
        let loader = ControlledEngagementPageLoader<TestEngagementItem>()
        let state = EngagementListSheetState<TestEngagementItem>(id: \.id) { cursor in
            await loader.load(after: cursor)
        }

        let firstOpen = Task { await state.reload() }
        await loader.waitForRequests(1)

        let reopened = Task { await state.reload() }
        await loader.waitForRequests(2)
        await loader.waitForCancellations(1)
        loader.complete(
            request: 1,
            with: .success(page(["share-reopened"], hasMore: true, endCursor: "share-reopened-cursor"))
        )
        await reopened.value

        loader.complete(request: 0, with: .failure(.graphQL("stale share error")))
        await firstOpen.value

        #expect(state.items.map(\.id) == ["share-reopened"])
        #expect(state.initialErrorMessage == nil)
        #expect(state.paginationErrorMessage == nil)
        #expect(state.cursor == "share-reopened-cursor")
        #expect(state.hasMore)
    }
}
