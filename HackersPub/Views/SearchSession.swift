import Foundation
import Observation

enum SearchResultSection: Hashable {
    case accounts
    case relatedAccounts
    case posts
}

private enum SearchRequestIntent: Equatable {
    case automatic
    case explicit
}

typealias SearchSuccessfulExplicitSearch = @MainActor (String) -> Void

struct SearchResults {
    var directActors: [SearchResultType] = []
    var relatedActors: [SearchResultType] = []
    var posts: [SearchResultType] = []
    var sectionFailures: [SearchResultSection: String] = [:]
    var errorMessage: String?

    var isEmpty: Bool {
        directActors.isEmpty && relatedActors.isEmpty && posts.isEmpty
    }

    var failureMessage: String? {
        errorMessage
            ?? sectionFailures[.posts]
            ?? sectionFailures[.accounts]
            ?? sectionFailures[.relatedAccounts]
    }
}

typealias SearchSessionRequest = @MainActor (String) async throws -> SearchResults

struct SearchSubmitRequest: Equatable {
    let id: Int
    let query: String
}

struct SearchRouterRequestCoordinator {
    private var handledRequestIDs: Set<UUID> = []
    private var suppressedAutomaticQueries: Set<String> = []

    mutating func handle(
        _ request: SearchRequest?,
        currentQuery: String,
        applyQuery: (String) -> Void,
        submit: (String) -> Void
    ) -> Bool {
        guard let request, handledRequestIDs.insert(request.id).inserted else { return false }
        let query = normalized(request.query)
        if currentQuery != query {
            suppressedAutomaticQueries.insert(query)
            applyQuery(query)
        }
        submit(query)
        return true
    }

    @discardableResult
    mutating func handleAutomaticInput(
        _ input: String,
        currentQuery: String,
        submit: (String) -> Void
    ) -> Bool {
        guard shouldSubmitAutomaticInput(input, currentQuery: currentQuery) else { return false }
        submit(input)
        return true
    }

    mutating func shouldSubmitAutomaticInput(_ input: String, currentQuery: String) -> Bool {
        let query = normalized(input)
        let current = normalized(currentQuery)

        suppressedAutomaticQueries = Set(suppressedAutomaticQueries.filter { $0 == current })

        guard query == current else { return false }
        return suppressedAutomaticQueries.remove(query) == nil
    }

    private func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Observable
@MainActor
final class SearchSession {
    private let request: SearchSessionRequest
    private let debounce: Duration
    private let onSuccessfulExplicitSearch: SearchSuccessfulExplicitSearch
    private var searchTask: Task<Void, Never>?
    private var requestGeneration = 0
    private var currentIntent: SearchRequestIntent = .automatic
    private var inputQueryToIgnoreAfterRecentSelection: String?

    private(set) var currentQuery = ""
    private(set) var results = SearchResults()
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var directActors: [SearchResultType] {
        results.directActors
    }

    var relatedActors: [SearchResultType] {
        results.relatedActors
    }

    var posts: [SearchResultType] {
        results.posts
    }

    var failureMessage: String? {
        errorMessage ?? results.failureMessage
    }

    init(
        request: @escaping SearchSessionRequest,
        debounce: Duration = .milliseconds(500),
        onSuccessfulExplicitSearch: @escaping SearchSuccessfulExplicitSearch = { _ in }
    ) {
        self.request = request
        self.debounce = debounce
        self.onSuccessfulExplicitSearch = onSuccessfulExplicitSearch
    }

    func inputChanged(_ rawQuery: String) {
        let query = normalizedQuery(rawQuery)
        if inputQueryToIgnoreAfterRecentSelection == query {
            inputQueryToIgnoreAfterRecentSelection = nil
            return
        }
        inputQueryToIgnoreAfterRecentSelection = nil
        start(query, delay: debounce, intent: .automatic)
    }

    func submit(_ rawQuery: String) {
        start(rawQuery, delay: .zero, intent: .explicit)
    }

    func selectRecent(_ rawQuery: String) {
        let query = normalizedQuery(rawQuery)
        inputQueryToIgnoreAfterRecentSelection = query
        start(query, delay: .zero, intent: .explicit)
    }

    func retry() {
        guard !currentQuery.isEmpty else { return }
        start(currentQuery, delay: .zero, intent: currentIntent)
    }

    func viewDidAppear(query rawQuery: String) {
        let query = normalizedQuery(rawQuery)
        guard !query.isEmpty, query != currentQuery || !isLoading else { return }
        start(query, delay: debounce, intent: .automatic)
    }

    func viewDidDisappear() {
        requestGeneration &+= 1
        searchTask?.cancel()
        searchTask = nil
        isLoading = false
        inputQueryToIgnoreAfterRecentSelection = nil
    }

    func removePosts(withRowIDs rowIDs: [String]) {
        guard !rowIDs.isEmpty else { return }

        requestGeneration &+= 1
        searchTask?.cancel()
        searchTask = nil
        isLoading = false
        results.posts.removeAll { rowIDs.contains($0.id) }
    }

    private func start(_ rawQuery: String, delay: Duration, intent: SearchRequestIntent) {
        let query = normalizedQuery(rawQuery)
        requestGeneration &+= 1
        let generation = requestGeneration

        searchTask?.cancel()
        searchTask = nil
        currentQuery = query
        currentIntent = intent
        errorMessage = nil
        results.errorMessage = nil
        results.sectionFailures = [:]

        guard !query.isEmpty else {
            results = SearchResults()
            isLoading = false
            return
        }

        isLoading = true
        searchTask = Task { [request] in
            do {
                try await Task.sleep(for: delay)
                let results = try await request(query)
                apply(results, query: query, intent: intent, for: generation)
            } catch is CancellationError {
                finishCancellation(for: generation)
            } catch {
                finishFailure(error, for: generation)
            }
        }
    }

    private func apply(
        _ incomingResults: SearchResults,
        query: String,
        intent: SearchRequestIntent,
        for generation: Int
    ) {
        guard generation == requestGeneration else { return }
        results = incomingResults
        isLoading = false
        errorMessage = incomingResults.errorMessage
        searchTask = nil

        if intent == .explicit, !incomingResults.isEmpty {
            onSuccessfulExplicitSearch(query)
        }
    }

    private func finishCancellation(for generation: Int) {
        guard generation == requestGeneration else { return }
        isLoading = false
        searchTask = nil
    }

    private func finishFailure(_ error: any Error, for generation: Int) {
        guard generation == requestGeneration else { return }
        isLoading = false
        errorMessage = error.localizedDescription
        searchTask = nil
    }

    func failureMessage(for section: SearchResultSection) -> String? {
        results.sectionFailures[section]
    }

    private func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
