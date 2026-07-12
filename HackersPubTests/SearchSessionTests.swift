import Foundation
@testable import HackersPub
import Testing

@MainActor
struct SearchSessionTests {
    @Test func staleNonCooperativeSuccessCannotOverwriteTheLatestQuery() async {
        let requests = ControlledSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)

        session.inputChanged("older")
        await requests.waitForRequestCount(1)

        session.inputChanged("newer")
        await requests.waitForRequestCount(2)

        requests.succeed(request: 1, with: .resolvedPost(id: "new", url: "https://example.com/new"))
        await Task.yield()

        requests.succeed(request: 0, with: .resolvedPost(id: "old", url: "https://example.com/old"))
        await Task.yield()

        #expect(session.posts.map(\.id) == ["resolved-post-new"])
        #expect(!session.isLoading)
    }

    @Test func sameQueryResubmissionOutranksItsEarlierCompletion() async {
        let requests = ControlledSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)

        session.inputChanged("same")
        await requests.waitForRequestCount(1)

        session.submit("same")
        await requests.waitForRequestCount(2)

        requests.succeed(request: 1, with: .resolvedPost(id: "new", url: "https://example.com/new"))
        await Task.yield()
        requests.succeed(request: 0, with: .resolvedPost(id: "old", url: "https://example.com/old"))
        await Task.yield()

        #expect(session.posts.map(\.id) == ["resolved-post-new"])
        #expect(!session.isLoading)
    }

    @Test func reappearingWithTheSameQueryInvalidatesTheEarlierRequest() async {
        let requests = ControlledSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)

        session.inputChanged("same")
        await requests.waitForRequestCount(1)

        session.viewDidDisappear()
        session.viewDidAppear(query: "same")
        await requests.waitForRequestCount(2)

        requests.succeed(request: 0, with: .resolvedPost(id: "old", url: "https://example.com/old"))
        await Task.yield()
        #expect(session.isLoading)

        requests.succeed(request: 1, with: .resolvedPost(id: "new", url: "https://example.com/new"))
        await Task.yield()

        #expect(session.posts.map(\.id) == ["resolved-post-new"])
        #expect(!session.isLoading)
    }

    @Test func staleFailureCannotReplaceLatestSuccessOrItsPresentationState() async {
        let requests = ControlledSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)

        session.inputChanged("older")
        await requests.waitForRequestCount(1)
        session.inputChanged("newer")
        await requests.waitForRequestCount(2)

        requests.succeed(request: 1, with: .resolvedPost(id: "new", url: "https://example.com/new"))
        await Task.yield()
        requests.fail(request: 0, with: SearchRequestFailure.offline)
        await Task.yield()

        #expect(session.posts.map(\.id) == ["resolved-post-new"])
        #expect(!session.isLoading)
        #expect(session.errorMessage == nil)
    }

    @Test func typedDeletionInvalidatesAnInFlightSearchBeforeItCanRestoreTheDeletedRow() async {
        let requests = ControlledSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)

        session.inputChanged("stable")
        await requests.waitForRequestCount(1)
        requests.succeed(request: 0, with: .resolvedPost(id: "deleted", url: "https://example.com/deleted"))
        await waitUntil { session.posts.map(\.id) == ["resolved-post-deleted"] }

        session.inputChanged("refresh")
        await requests.waitForRequestCount(2)
        session.removePosts(withRowIDs: ["resolved-post-deleted"])

        requests.succeed(request: 1, with: .resolvedPost(id: "deleted", url: "https://example.com/deleted"))
        await Task.yield()

        #expect(session.posts.isEmpty)
        #expect(!session.isLoading)
    }

    @Test func disappearingSilentlyInvalidatesALateFailureBeforeTheSameQueryReappears() async {
        let requests = ControlledSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)

        session.inputChanged("same")
        await requests.waitForRequestCount(1)

        session.viewDidDisappear()
        requests.fail(request: 0, with: SearchRequestFailure.offline)
        await Task.yield()

        #expect(session.posts.isEmpty)
        #expect(!session.isLoading)
        #expect(session.errorMessage == nil)

        session.viewDidAppear(query: "same")
        await requests.waitForRequestCount(2)
        requests.succeed(request: 1, with: .resolvedPost(id: "new", url: "https://example.com/new"))
        await waitUntil { session.posts.map(\.id) == ["resolved-post-new"] }

        #expect(session.posts.map(\.id) == ["resolved-post-new"])
        #expect(session.errorMessage == nil)
    }

    @Test func failedSearchRetainsResultsAndRetriesTheCurrentQuery() async {
        let requests = ControlledSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)

        session.inputChanged("stable")
        await requests.waitForRequestCount(1)
        requests.succeed(request: 0, with: .resolvedPost(id: "stable", url: "https://example.com/stable"))
        await Task.yield()

        session.inputChanged("retry-this")
        await requests.waitForRequestCount(2)
        requests.fail(request: 1, with: SearchRequestFailure.offline)
        await waitUntil { session.errorMessage == "offline" }

        #expect(session.posts.map(\.id) == ["resolved-post-stable"])
        #expect(session.errorMessage == "offline")

        session.retry()
        await requests.waitForRequestCount(3)
        #expect(requests.requestedQueries == ["stable", "retry-this", "retry-this"])

        requests.succeed(request: 2, with: .resolvedPost(id: "retried", url: "https://example.com/retried"))
        await Task.yield()

        #expect(session.posts.map(\.id) == ["resolved-post-retried"])
        #expect(session.errorMessage == nil)
    }

    @Test func onlyExplicitNonemptySearchesBecomeRecent() async {
        let requests = ControlledSearchRequest()
        var recordedQueries: [String] = []
        let session = SearchSession(
            request: requests.load,
            debounce: .zero,
            onSuccessfulExplicitSearch: { recordedQueries.append($0) }
        )

        session.inputChanged("typing")
        await requests.waitForRequestCount(1)
        requests.succeed(request: 0, with: .resolvedPost(id: "typing", url: "https://example.com/typing"))
        await Task.yield()

        session.submit("empty")
        await requests.waitForRequestCount(2)
        requests.succeed(request: 1, with: SearchResults())
        await Task.yield()

        session.submit("failed")
        await requests.waitForRequestCount(3)
        requests.fail(request: 2, with: SearchRequestFailure.offline)
        await Task.yield()

        #expect(recordedQueries.isEmpty)
    }

    @Test func explicitSearchAndItsRetryRecordNormalizedQueriesAfterSuccess() async {
        let requests = ControlledSearchRequest()
        var recordedQueries: [String] = []
        let session = SearchSession(
            request: requests.load,
            debounce: .zero,
            onSuccessfulExplicitSearch: { recordedQueries.append($0) }
        )

        session.submit("  saved  ")
        await requests.waitForRequestCount(1)
        requests.succeed(request: 0, with: .resolvedPost(id: "saved", url: "https://example.com/saved"))
        await Task.yield()

        session.submit("retry")
        await requests.waitForRequestCount(2)
        requests.fail(request: 1, with: SearchRequestFailure.offline)
        await Task.yield()

        session.retry()
        await requests.waitForRequestCount(3)
        requests.succeed(request: 2, with: .resolvedPost(id: "retry", url: "https://example.com/retry"))
        await Task.yield()

        #expect(recordedQueries == ["saved", "retry"])
    }

    @Test func selectingRecentSearchSuppressesItsFollowupAutomaticInputAndRecordsOnce() async {
        let requests = ControlledSearchRequest()
        var recordedQueries: [String] = []
        let session = SearchSession(
            request: requests.load,
            debounce: .zero,
            onSuccessfulExplicitSearch: { recordedQueries.append($0) }
        )

        session.selectRecent("saved")
        session.inputChanged("saved")
        await requests.waitForRequestCount(1)

        requests.succeed(request: 0, with: .resolvedPost(id: "saved", url: "https://example.com/saved"))
        await waitUntil { recordedQueries == ["saved"] }

        #expect(requests.requestedQueries == ["saved"])
        #expect(recordedQueries == ["saved"])
    }
}

@MainActor
struct SearchRouterRequestCoordinatorTests {
    @Test func routerRequestsCreateOneExplicitGenerationForChangedEqualAndBackToBackQueries() async {
        let requests = ControlledSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)
        var coordinator = SearchRouterRequestCoordinator()
        var searchText = ""

        let changedRequest = SearchRequest(query: "swift")
        let handledChangedRequest = handle(
            changedRequest, coordinator: &coordinator, searchText: &searchText, session: session
        )
        #expect(handledChangedRequest)
        let suppressesChangedAutomaticInput = coordinator.shouldSubmitAutomaticInput(
            searchText,
            currentQuery: searchText
        )
        #expect(!suppressesChangedAutomaticInput)
        await requests.waitForRequestCount(1)

        let equalRequest = SearchRequest(query: "swift")
        let handledEqualRequest = handle(
            equalRequest, coordinator: &coordinator, searchText: &searchText, session: session
        )
        #expect(handledEqualRequest)
        await requests.waitForRequestCount(2)

        let firstBackToBackRequest = SearchRequest(query: "one")
        let handledFirstBackToBackRequest = handle(
            firstBackToBackRequest, coordinator: &coordinator, searchText: &searchText, session: session
        )
        #expect(handledFirstBackToBackRequest)
        let firstBackToBackQuery = searchText
        let startedFirstBackToBackRequest = await requests.waitForRequestCount(3)
        #expect(startedFirstBackToBackRequest)

        let secondBackToBackRequest = SearchRequest(query: "two")
        let handledSecondBackToBackRequest = handle(
            secondBackToBackRequest, coordinator: &coordinator, searchText: &searchText, session: session
        )
        #expect(handledSecondBackToBackRequest)
        let secondBackToBackQuery = searchText

        let suppressesFirstBackToBackAutomaticInput = coordinator.shouldSubmitAutomaticInput(
            firstBackToBackQuery,
            currentQuery: searchText
        )
        let suppressesSecondBackToBackAutomaticInput = coordinator.shouldSubmitAutomaticInput(
            secondBackToBackQuery,
            currentQuery: searchText
        )
        #expect(!suppressesFirstBackToBackAutomaticInput)
        #expect(!suppressesSecondBackToBackAutomaticInput)
        let startedSecondBackToBackRequest = await requests.waitForRequestCount(4)
        #expect(startedSecondBackToBackRequest)

        #expect(requests.requestedQueries == ["swift", "swift", "one", "two"])
        session.viewDidDisappear()
    }

    @Test func prepopulatedRouterRequestSubmitsOnceAndAcknowledgesItsIdentityAcrossReappearance() async {
        let requests = ControlledSearchRequest()
        let session = SearchSession(request: requests.load, debounce: .zero)
        var coordinator = SearchRouterRequestCoordinator()
        var searchText = ""
        let initialRequest = SearchRequest(query: "cold start")

        let handledInitialRequest = handle(
            initialRequest, coordinator: &coordinator, searchText: &searchText, session: session
        )
        #expect(handledInitialRequest)
        let startedInitialRequest = await requests.waitForRequestCount(1)
        #expect(startedInitialRequest)
        #expect(searchText == "cold start")

        let replayedInitialRequest = handle(
            initialRequest, coordinator: &coordinator, searchText: &searchText, session: session
        )
        #expect(!replayedInitialRequest)
        await Task.yield()
        #expect(requests.requestedQueries == ["cold start"])

        let replacementRequest = SearchRequest(query: "cold start")
        let handledReplacementRequest = handle(
            replacementRequest, coordinator: &coordinator, searchText: &searchText, session: session
        )
        #expect(handledReplacementRequest)
        let startedReplacementRequest = await requests.waitForRequestCount(2)
        #expect(startedReplacementRequest)
        #expect(requests.requestedQueries == ["cold start", "cold start"])
        session.viewDidDisappear()
    }

    private func handle(
        _ request: SearchRequest,
        coordinator: inout SearchRouterRequestCoordinator,
        searchText: inout String,
        session: SearchSession
    ) -> Bool {
        coordinator.handle(
            request,
            currentQuery: searchText,
            applyQuery: { searchText = $0 },
            submit: session.submit
        )
    }
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0 ..< 100 {
        if condition() {
            return
        }
        await Task.yield()
    }
}

@MainActor
private final class ControlledSearchRequest {
    private var continuations: [CheckedContinuation<SearchResults, any Error>] = []
    private(set) var requestedQueries: [String] = []

    func load(query: String) async throws -> SearchResults {
        requestedQueries.append(query)
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    @discardableResult
    func waitForRequestCount(_ count: Int) async -> Bool {
        for _ in 0 ..< 100 {
            if requestedQueries.count >= count {
                return true
            }
            await Task.yield()
        }
        return requestedQueries.count >= count
    }

    func succeed(request: Int, with result: SearchResultType) {
        continuations[request].resume(returning: SearchResults(posts: [result]))
    }

    func succeed(request: Int, with results: SearchResults) {
        continuations[request].resume(returning: results)
    }

    func fail(request: Int, with error: any Error) {
        continuations[request].resume(throwing: error)
    }
}

private enum SearchRequestFailure: LocalizedError {
    case offline

    var errorDescription: String? {
        "offline"
    }
}
