@preconcurrency import Apollo
import Foundation

#if DEBUG
    enum UITestLaunchConfiguration {
        private static let searchStubArgument = "-com.hackerspub.ui-test.search-stub"
        private static let seedRecentSearchArgument = "-com.hackerspub.ui-test.seed-recent-search"
        private static let resetSearchStateArgument = "-com.hackerspub.ui-test.reset-search-state"
        private static let forceGuestArgument = "-com.hackerspub.ui-test.force-guest"
        private static let noLiveRootNetworkArgument = "-com.hackerspub.ui-test.no-live-root-network"
        private static let seedRouterSearchArgument = "-com.hackerspub.ui-test.seed-router-search"

        private static var arguments: [String] {
            ProcessInfo.processInfo.arguments
        }

        static var usesSearchStub: Bool {
            usesSearchStub(arguments: arguments)
        }

        static func usesSearchStub(arguments: [String]) -> Bool {
            arguments.contains(searchStubArgument)
        }

        static var seedsRecentSearch: Bool {
            arguments.contains(seedRecentSearchArgument)
        }

        static var resetsSearchState: Bool {
            arguments.contains(resetSearchStateArgument)
        }

        static var forcesGuestSession: Bool {
            arguments.contains(forceGuestArgument)
        }

        static var disablesRootTimelineNetwork: Bool {
            disablesRootTimelineNetwork(arguments: arguments)
        }

        static func disablesRootTimelineNetwork(arguments: [String]) -> Bool {
            arguments.contains(noLiveRootNetworkArgument)
        }

        static var seedsRouterSearch: Bool {
            arguments.contains(seedRouterSearchArgument)
        }

        static let seededRouterSearchQuery = "ui test router search"
    }
#endif

struct SearchActor: Identifiable, Hashable {
    let id: String
    let name: String?
    let handle: String
    let avatarURL: String

    init(id: String, name: String?, handle: String, avatarURL: String) {
        self.id = id
        self.name = name
        self.handle = handle
        self.avatarURL = avatarURL
    }

    init(_ actor: HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node.Actor) {
        self.init(id: actor.id, name: actor.name, handle: actor.handle, avatarURL: actor.avatarUrl)
    }

    init(_ actor: HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle) {
        self.init(id: actor.id, name: actor.name, handle: actor.handle, avatarURL: actor.avatarUrl)
    }
}

struct SearchPostIdentity: Hashable {
    let value: String
}

struct SearchPostMatch {
    let result: SearchResultType
    let actor: SearchActor
    let postIdentity: SearchPostIdentity

    init(result: SearchResultType, actor: SearchActor, postIdentity: String? = nil) {
        self.result = result
        self.actor = actor
        guard let postIdentity = postIdentity ?? result.postIdentity?.value else {
            preconditionFailure("Search post matches must have a post identity")
        }
        self.postIdentity = SearchPostIdentity(value: postIdentity)
    }

    init(post: HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node) {
        self.init(result: .post(post), actor: SearchActor(post.actor), postIdentity: post.id)
    }
}

private extension SearchResultType {
    var postIdentity: SearchPostIdentity? {
        switch self {
        case let .post(post):
            SearchPostIdentity(value: post.id)
        case let .resolvedPost(id, _):
            SearchPostIdentity(value: id)
        case .actor:
            nil
        }
    }
}

struct SearchNetwork {
    let searchPosts: @MainActor (String) async throws -> [SearchPostMatch]
    let searchActors: @MainActor (String) async throws -> [SearchActor]
    let searchObjectURL: @MainActor (String) async throws -> String?
    let resolvePostID: @MainActor (String) async throws -> String?
    let canSearchActors: @MainActor () -> Bool

    init(
        searchPosts: @escaping @MainActor (String) async throws -> [SearchPostMatch],
        searchActors: @escaping @MainActor (String) async throws -> [SearchActor],
        searchObjectURL: @escaping @MainActor (String) async throws -> String?,
        resolvePostID: @escaping @MainActor (String) async throws -> String?,
        canSearchActors: @escaping @MainActor () -> Bool = { true }
    ) {
        self.searchPosts = searchPosts
        self.searchActors = searchActors
        self.searchObjectURL = searchObjectURL
        self.resolvePostID = resolvePostID
        self.canSearchActors = canSearchActors
    }

    @MainActor
    static let live = SearchNetwork(
        searchPosts: { query in
            let response = try await apolloClient.fetch(query: HackersPub.SearchPostQuery(query: query))
            if let error = response.errors?.first {
                throw error
            }
            return response.data?.searchPost.edges.map { SearchPostMatch(post: $0.node) } ?? []
        },
        searchActors: { prefix in
            let response = try await apolloClient.fetch(
                query: HackersPub.SearchActorsByHandleQuery(prefix: prefix)
            )
            if let error = response.errors?.first {
                throw error
            }
            return response.data?.searchActorsByHandle.map(SearchActor.init) ?? []
        },
        searchObjectURL: { query in
            let response = try await apolloClient.fetch(query: HackersPub.SearchObjectQuery(query: query))
            if let error = response.errors?.first {
                throw error
            }
            return response.data?.searchObject?.asSearchedObject?.url
        },
        resolvePostID: { url in
            let response = try await apolloClient.fetch(query: HackersPub.PostByUrlQuery(url: url))
            if let error = response.errors?.first {
                throw error
            }
            return response.data?.postByUrl?.id
        },
        canSearchActors: { AuthManager.shared.isAuthenticated }
    )

    #if DEBUG
        @MainActor
        static func configured(arguments: [String], live: SearchNetwork) -> SearchNetwork {
            guard UITestLaunchConfiguration.usesSearchStub(arguments: arguments) else {
                return live
            }
            return uiTestStub
        }

        @MainActor
        private static let uiTestStub = SearchNetwork(
            searchPosts: { _ in
                [
                    SearchPostMatch(
                        result: .resolvedPost(id: "ui-test-post", url: "https://example.com/ui-test-post"),
                        actor: SearchActor(
                            id: "ui-test-actor",
                            name: "UI test actor",
                            handle: "@ui-test@example.com",
                            avatarURL: "https://example.com/avatar.png"
                        )
                    )
                ]
            },
            searchActors: { _ in [] },
            searchObjectURL: { _ in nil },
            resolvePostID: { _ in nil },
            canSearchActors: { false }
        )
    #endif
}

@MainActor
struct SearchService {
    private let network: SearchNetwork

    init() {
        #if DEBUG
            network = SearchNetwork.configured(
                arguments: ProcessInfo.processInfo.arguments,
                live: .live
            )
        #else
            network = .live
        #endif
    }

    init(network: SearchNetwork) {
        self.network = network
    }

    func search(query: String) async throws -> SearchResults {
        async let postsTask = capture { try await network.searchPosts(query) }
        async let objectTask = capture { try await network.searchObjectURL(query) }

        let actorOutcome: Result<[SearchActor], Error>
        if network.canSearchActors() {
            actorOutcome = try await capture { try await network.searchActors(query) }
        } else {
            actorOutcome = .success([])
        }

        let (postOutcome, objectOutcome) = try await(postsTask, objectTask)
        try Task.checkCancellation()

        var results = SearchResults()
        var seenActorIDs = Set<String>()
        var seenPostIdentities = Set<SearchPostIdentity>()

        switch actorOutcome {
        case let .success(actors):
            appendDirectActors(actors, to: &results, seenActorIDs: &seenActorIDs)
        case let .failure(error):
            results.sectionFailures[.accounts] = error.localizedDescription
        }

        switch postOutcome {
        case let .success(postMatches):
            results.posts = postMatches.map(\.result)
            seenPostIdentities.formUnion(postMatches.map(\.postIdentity))
            appendRelatedActors(from: postMatches, to: &results, seenActorIDs: &seenActorIDs)
        case let .failure(error):
            let message = error.localizedDescription
            results.sectionFailures[.posts] = message
            results.sectionFailures[.relatedAccounts] = message
        }

        switch objectOutcome {
        case let .success(objectURL):
            if let objectURL {
                try await appendResolvedObject(
                    from: objectURL,
                    to: &results,
                    seenActorIDs: &seenActorIDs,
                    seenPostIdentities: &seenPostIdentities
                )
            }
        case let .failure(error):
            results.errorMessage = error.localizedDescription
        }

        return results
    }

    private func appendDirectActors(
        _ actors: [SearchActor],
        to results: inout SearchResults,
        seenActorIDs: inout Set<String>
    ) {
        for actor in actors where seenActorIDs.insert(actor.id).inserted {
            results.directActors.append(.actor(actor))
        }
    }

    private func appendRelatedActors(
        from postMatches: [SearchPostMatch],
        to results: inout SearchResults,
        seenActorIDs: inout Set<String>
    ) {
        for match in postMatches where seenActorIDs.insert(match.actor.id).inserted {
            results.relatedActors.append(.actor(match.actor))
        }
    }

    private func appendResolvedObject(
        from objectURL: String,
        to results: inout SearchResults,
        seenActorIDs: inout Set<String>,
        seenPostIdentities: inout Set<SearchPostIdentity>
    ) async throws {
        guard let resolvedURL = URL(string: objectURL) else { return }

        if case let .profile(handle) = HackersPubURLRouter.resolve(resolvedURL) {
            guard network.canSearchActors() else { return }
            let actorOutcome = try await capture { try await network.searchActors(handle) }
            switch actorOutcome {
            case let .success(actors):
                appendDirectActors(actors, to: &results, seenActorIDs: &seenActorIDs)
            case let .failure(error):
                results.sectionFailures[.accounts] = error.localizedDescription
            }
            return
        }

        let postOutcome = try await capture { try await network.resolvePostID(objectURL) }
        switch postOutcome {
        case let .success(postID):
            guard let postID else { return }
            guard seenPostIdentities.insert(SearchPostIdentity(value: postID)).inserted else { return }
            results.posts.append(.resolvedPost(id: postID, url: objectURL))
        case let .failure(error):
            results.errorMessage = error.localizedDescription
        }
    }

    private func capture<Value>(
        _ request: () async throws -> Value
    ) async throws -> Result<Value, Error> {
        do {
            let value = try await request()
            try Task.checkCancellation()
            return .success(value)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .failure(error)
        }
    }
}
