import Foundation
@_spi(Unsafe) import ApolloAPI
@testable import HackersPub
import Testing

private typealias SearchPostNode = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node

struct SearchViewWiringTests {
    @Test @MainActor func automaticInputPolicySuppressesRouterEchoesAndForwardsToTheSession() async {
        var routerCoordinator = SearchRouterRequestCoordinator()
        var searchText = ""
        var routerSubmissions: [String] = []
        let routerRequest = SearchRequest(query: "router")

        let handledRouterRequest = routerCoordinator.handle(
            routerRequest,
            currentQuery: searchText,
            applyQuery: { searchText = $0 },
            submit: { routerSubmissions.append($0) }
        )
        #expect(handledRouterRequest)

        var automaticRouterSubmissions: [String] = []
        let forwardsRouterEcho = routerCoordinator.handleAutomaticInput(
            routerRequest.query,
            currentQuery: searchText,
            submit: { automaticRouterSubmissions.append($0) }
        )
        #expect(!forwardsRouterEcho)
        #expect(routerSubmissions == ["router"])
        #expect(automaticRouterSubmissions.isEmpty)

        var requestedQueries: [String] = []
        let session = SearchSession(
            request: { query in
                requestedQueries.append(query)
                return SearchResults()
            },
            debounce: .zero
        )
        var sessionCoordinator = SearchRouterRequestCoordinator()

        let forwardsTypedInput = sessionCoordinator.handleAutomaticInput(
            "typing",
            currentQuery: "typing",
            submit: session.inputChanged
        )
        #expect(forwardsTypedInput)
        await waitUntil { requestedQueries == ["typing"] }

        session.selectRecent("saved")
        let forwardsRecentSelectionInput = sessionCoordinator.handleAutomaticInput(
            "saved",
            currentQuery: "saved",
            submit: session.inputChanged
        )
        #expect(forwardsRecentSelectionInput)
        await waitUntil { requestedQueries == ["typing", "saved"] }

        #expect(requestedQueries == ["typing", "saved"])
        session.viewDidDisappear()
    }

    @Test func keyboardSearchSubmitIsCapturedByTheSearchableChainAndForwardedOnce() throws {
        let contentSource = try source(named: "ContentView.swift")
        let searchSource = try source(named: "SearchView.swift")

        #expect(contentSource.contains("@State private var searchSubmitRequest"))
        let searchableRange = try #require(contentSource.range(of: ".searchable(text: $searchText)"))
        let submitRange = try #require(contentSource.range(of: ".onSubmit(of: .search)"))
        #expect(searchableRange.lowerBound < submitRange.lowerBound)
        #expect(contentSource.contains("SearchSubmitRequest("))
        #expect(block(after: ".onChange(of: searchSubmitRequest)", in: searchSource)
            .contains("searchSession.submit(submitRequest.query)"))
        #expect(!searchSource.contains(".onSubmit"))
    }

    @Test @MainActor func identicalRouterSearchRequestsCarryDistinctNoncesAndForwardIndividually() throws {
        let coordinator = NavigationCoordinator()
        let consumer = ContentViewSearchRequestConsumer(navigationCoordinator: coordinator)
        var forwardedRequests: [SearchRequest] = []

        coordinator.openSearch(query: "swift")
        let firstRequest = try #require(consumer.consume(
            forward: { forwardedRequests.append($0) }
        ))
        coordinator.openSearch(query: "swift")
        let secondRequest = try #require(consumer.consume(
            forward: { forwardedRequests.append($0) }
        ))

        #expect(firstRequest.query == "swift")
        #expect(secondRequest.query == "swift")
        #expect(firstRequest.id != secondRequest.id)
        #expect(forwardedRequests == [firstRequest, secondRequest])
    }

    @Test func searchViewPresentsFailuresAndRoutesBothRetryPathsToTheSession() throws {
        let source = try source(named: "SearchView.swift")
        let emptyFailureBranch = block(
            after: "else if let errorMessage = searchSession.failureMessage, searchSession.results.isEmpty",
            in: source
        )
        let inlineFailureBranch = block(after: "InlineLoadFailureView(message: errorMessage)", in: source)

        #expect(emptyFailureBranch.contains("LoadFailureView(message: errorMessage)"))
        #expect(emptyFailureBranch.contains("searchSession.retry()"))
        #expect(inlineFailureBranch.contains("searchSession.retry()"))
    }

    @Test func everySearchResultVariantHasOneNavigationOwnerAndVisibleDestination() {
        let actor = SearchActor(
            id: "actor",
            name: "Actor Name",
            handle: "@actor@example.com",
            avatarURL: "https://example.com/avatar.png"
        )
        let normalPost = searchPost(id: "normal", typename: "Note")
        let sharedPost = searchPost(id: "wrapper", typename: "Note", sharedPostID: "original")
        let article = searchPost(id: "article", typename: "Article")

        #expect(SearchResultType.actor(actor).navigationPlan == SearchResultNavigationPlan(
            owner: .actorRow,
            destination: .profile(handle: actor.handle)
        ))
        #expect(SearchResultType.post(normalPost).navigationPlan == SearchResultNavigationPlan(
            owner: .postView,
            destination: .post(id: "normal")
        ))
        #expect(SearchResultType.post(sharedPost).navigationPlan == SearchResultNavigationPlan(
            owner: .postView,
            destination: .post(id: "original")
        ))
        #expect(SearchResultType.post(article).navigationPlan == SearchResultNavigationPlan(
            owner: .postView,
            destination: .post(id: "article")
        ))
        #expect(SearchResultType.resolvedPost(
            id: "resolved",
            url: "https://example.com/resolved"
        ).navigationPlan == SearchResultNavigationPlan(
            owner: .resolvedPostRow,
            destination: .post(id: "resolved")
        ))
    }

    @Test func searchViewCompositionDoesNotWrapActorOrPostOwnedControls() throws {
        let source = try source(named: "SearchView.swift")
        let directActors = block(after: "ForEach(directActors", in: source)
        let relatedActors = block(after: "ForEach(relatedActors", in: source)
        let posts = block(after: "ForEach(posts", in: source)
        let resultRow = block(after: "struct SearchResultRow: View", in: source)

        #expect(!directActors.contains("NavigationLink"))
        #expect(!relatedActors.contains("NavigationLink"))
        #expect(posts.occurrenceCount(of: "NavigationLink") == 1)
        #expect(posts.contains("case .post:"))
        #expect(resultRow.occurrenceCount(of: "NavigationLink(value:") == 1)
        #expect(resultRow.contains(".accessibilityElement(children: .ignore)"))
        #expect(resultRow.contains(".accessibilityLabel(actorAccessibilityLabel(actor))"))
        #expect(resultRow.contains(#".accessibilityIdentifier("search.result.actor.\(actor.id)")"#))
    }

    @Test func searchViewUsesTheRecentStoreForExplicitSuccessfulSearchesAndManagement() throws {
        let source = try source(named: "SearchView.swift")

        #expect(source.contains("@State private var recentSearchStore: SearchRecentStore"))
        #expect(source.contains("onSuccessfulExplicitSearch:"))
        #expect(block(after: "ForEach(recentSearches", in: source).contains("searchSession.selectRecent(query)"))
        #expect(source.contains("recentSearchStore.delete(query)"))
        #expect(source.contains("recentSearchStore.clear()"))
        #expect(source.contains("search.initial.description"))
        #expect(!source.contains("addToRecentSearches"))
    }

    @Test func searchStringsHaveInitialAndRecentManagementCopyInBothSupportedLocales() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let requiredKeys = [
            "search.initial.description",
            "search.recent.clear",
            "search.recent.delete"
        ]

        for locale in ["en", "ko"] {
            let strings = try String(
                contentsOf: repositoryRoot.appendingPathComponent("HackersPub/\(locale).lproj/Localizable.strings"),
                encoding: .utf8
            )
            for key in requiredKeys {
                #expect(strings.contains("\"\(key)\""))
            }
        }
    }

    private func source(named filename: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent("HackersPub/Views/\(filename)"),
            encoding: .utf8
        )
    }

    private func searchPost(
        id: String,
        typename: String,
        sharedPostID: String? = nil
    ) -> SearchPostNode {
        let sharedPost = sharedPostID.map { id in
            DataDict(
                data: ["__typename": "Note", "id": id],
                fulfilledFragments: []
            )
        }
        return SearchPostNode(_dataDict: DataDict(
            data: [
                "__typename": typename,
                "id": id,
                "sharedPost": sharedPost
            ],
            fulfilledFragments: [ObjectIdentifier(SearchPostNode.self)]
        ))
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

    private func block(after marker: String, in source: String) -> String {
        guard let markerRange = source.range(of: marker),
              let openingBrace = source[markerRange.upperBound...].firstIndex(of: "{")
        else {
            return ""
        }

        var depth = 0
        var index = openingBrace
        while index < source.endIndex {
            switch source[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(source[openingBrace ... index])
                }
            default:
                break
            }
            index = source.index(after: index)
        }
        return ""
    }
}

private extension String {
    func occurrenceCount(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
}
