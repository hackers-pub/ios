@preconcurrency import Apollo
import Foundation

private typealias ActorProfileQueryActor = HackersPub.ActorByHandleQuery.Data.ActorByHandle
private typealias ActorProfilePostNode = ActorProfileQueryActor.Posts.Edge.Node

extension ActorProfileView {
    func loadInitialPosts(
        cachePolicy: CachePolicy.Query.SingleResponse
    ) async {
        guard let request = profilePostsRequestCoordinator.beginInitialLoadIfNeeded() else {
            return
        }

        postsPageState.isLoading = true
        var didLoadInitial = false
        defer {
            if profilePostsRequestCoordinator.finish(
                request,
                didLoadInitial: didLoadInitial
            ) {
                postsPageState.isLoading = false
            }
        }

        do {
            didLoadInitial = try await loadFirstPage(
                cachePolicy: cachePolicy,
                for: request
            )
        } catch is CancellationError {
            return
        } catch {
            guard profilePostsRequestCoordinator.isCurrent(request) else {
                return
            }
            postsPageState.errorMessage = error.localizedDescription
        }
    }

    func refreshProfile() async {
        guard let request = profilePostsRequestCoordinator.beginRefresh() else {
            return
        }

        postsPageState.isLoading = selectedTab == .posts && posts.isEmpty
        let didLoadInitial = await refreshPosts(for: request)
        guard profilePostsRequestCoordinator.finish(
            request,
            didLoadInitial: didLoadInitial
        ) else {
            return
        }

        postsPageState.isLoading = false
        await refreshSelectedTab()
    }

    func loadSelectedTabIfNeeded() async {
        switch selectedTab {
        case .posts:
            if !postsPageState.hasLoaded {
                await loadInitialPosts(cachePolicy: .networkFirst)
            }
        case .notes:
            if !notesPageState.hasLoaded {
                await loadInitialNotes(cachePolicy: .networkFirst)
            }
        case .articles:
            if !articlesPageState.hasLoaded {
                await loadInitialArticles(cachePolicy: .networkFirst)
            }
        }
    }

    func loadMorePosts() async {
        guard let cursor = postsPageState.endCursor,
              postsPageState.hasNextPage,
              let request = profilePostsRequestCoordinator.beginLoadMore()
        else {
            return
        }

        postsPageState.isLoading = true
        defer {
            if profilePostsRequestCoordinator.finish(request, didLoadInitial: false) {
                postsPageState.isLoading = false
            }
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorByHandleQuery(
                    handle: actorData.handle,
                    after: .some(cursor),
                    before: nil,
                    first: 20,
                    last: nil
                ),
                cachePolicy: .networkOnly
            )
            try Task.checkCancellation()
            guard profilePostsRequestCoordinator.isCurrent(request),
                  let refreshedActor = try actorProfile(from: response, for: request)
            else {
                return
            }

            actorData = refreshedActor
            let appendedCount = appendUniquePosts(
                refreshedActor.posts.edges.map { $0.node }
            )
            _ = postsPageState.applyLoadMorePage(
                appendedCount: appendedCount,
                nextEndCursor: refreshedActor.posts.pageInfo.endCursor,
                hasNextPage: refreshedActor.posts.pageInfo.hasNextPage
            )
        } catch is CancellationError {
            return
        } catch {
            guard profilePostsRequestCoordinator.isCurrent(request) else {
                return
            }
            postsPageState.errorMessage = error.localizedDescription
        }
    }

    func loadNewerPosts() async {
        guard postsPageState.startCursor != nil,
              let request = profilePostsRequestCoordinator.beginLoadNewer()
        else {
            return
        }

        postsPageState.isLoading = true
        defer {
            if profilePostsRequestCoordinator.finish(request, didLoadInitial: false) {
                postsPageState.isLoading = false
            }
        }

        do {
            try await fetchNewerPosts(for: request)
        } catch is CancellationError {
            return
        } catch {
            guard profilePostsRequestCoordinator.isCurrent(request) else {
                return
            }
            postsPageState.errorMessage = error.localizedDescription
        }
    }

    private func refreshPosts(for request: ActorProfilePostRequest) async -> Bool {
        do {
            if posts.isEmpty || postsPageState.startCursor == nil {
                return try await loadFirstPage(cachePolicy: .networkOnly, for: request)
            }

            try await fetchNewerPosts(for: request)
            return false
        } catch is CancellationError {
            return false
        } catch {
            guard profilePostsRequestCoordinator.isCurrent(request) else {
                return false
            }
            postsPageState.errorMessage = error.localizedDescription
            return false
        }
    }

    private func refreshSelectedTab() async {
        switch selectedTab {
        case .posts:
            break
        case .notes:
            await refreshNotes()
        case .articles:
            await refreshArticles()
        }
    }

    private func loadFirstPage(
        cachePolicy: CachePolicy.Query.SingleResponse,
        for request: ActorProfilePostRequest
    ) async throws -> Bool {
        let response = try await apolloClient.fetch(
            query: HackersPub.ActorByHandleQuery(
                handle: actorData.handle,
                after: nil,
                before: nil,
                first: 20,
                last: nil
            ),
            cachePolicy: cachePolicy
        )
        try Task.checkCancellation()
        guard profilePostsRequestCoordinator.isCurrent(request),
              let refreshedActor = try actorProfile(from: response, for: request)
        else {
            return false
        }

        replacePosts(with: refreshedActor)
        return true
    }

    private func fetchNewerPosts(for request: ActorProfilePostRequest) async throws {
        guard let cursor = postsPageState.startCursor else {
            return
        }
        let response = try await apolloClient.fetch(
            query: HackersPub.ActorByHandleQuery(
                handle: actorData.handle,
                after: nil,
                before: .some(cursor),
                first: nil,
                last: 20
            ),
            cachePolicy: .networkOnly
        )
        try Task.checkCancellation()
        guard profilePostsRequestCoordinator.isCurrent(request),
              let refreshedActor = try actorProfile(from: response, for: request)
        else {
            return
        }

        actorData = refreshedActor
        let previousStartCursor = postsPageState.startCursor
        let prependedCount = prependUniquePosts(refreshedActor.posts.edges.map { $0.node })
        let nextStartCursor = refreshedActor.posts.pageInfo.startCursor
        postsPageState.hasLoaded = true
        postsPageState.hasPreviousPage = prependedCount > 0 || nextStartCursor != previousStartCursor
            ? refreshedActor.posts.pageInfo.hasPreviousPage
            : false
        if let nextStartCursor {
            postsPageState.startCursor = nextStartCursor
        }
        if postsPageState.endCursor == nil {
            postsPageState.endCursor = refreshedActor.posts.pageInfo.endCursor
        }
        postsPageState.errorMessage = nil
    }

    private func actorProfile(
        from response: GraphQLResponse<HackersPub.ActorByHandleQuery>,
        for request: ActorProfilePostRequest
    ) throws -> ActorProfileQueryActor? {
        if let error = response.errors?.first {
            throw error
        }
        guard let refreshedActor = response.data?.actorByHandle else {
            throw ActorRelationshipServiceError.actorNotFound
        }
        guard refreshedActor.id == request.profileID else {
            return nil
        }
        return refreshedActor
    }

    private func replacePosts(with refreshedActor: ActorProfileQueryActor) {
        actorData = refreshedActor
        posts = refreshedActor.posts.edges.map { $0.node }
        postsPageState.hasLoaded = true
        postsPageState.hasPreviousPage = refreshedActor.posts.pageInfo.hasPreviousPage
        postsPageState.hasNextPage = refreshedActor.posts.pageInfo.hasNextPage
        postsPageState.startCursor = refreshedActor.posts.pageInfo.startCursor
        postsPageState.endCursor = refreshedActor.posts.pageInfo.endCursor
        postsPageState.errorMessage = nil
    }

    @discardableResult
    private func prependUniquePosts(_ incoming: [ActorProfilePostNode]) -> Int {
        let existingIDs = Set(posts.map(\.id))
        let uniquePosts = incoming.filter { !existingIDs.contains($0.id) }
        posts = uniquePosts + posts
        return uniquePosts.count
    }

    @discardableResult
    private func appendUniquePosts(_ incoming: [ActorProfilePostNode]) -> Int {
        let existingIDs = Set(posts.map(\.id))
        let uniquePosts = incoming.filter { !existingIDs.contains($0.id) }
        posts.append(contentsOf: uniquePosts)
        return uniquePosts.count
    }
}
