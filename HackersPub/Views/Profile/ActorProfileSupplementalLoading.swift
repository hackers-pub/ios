@preconcurrency import Apollo
import Foundation

private typealias ActorProfileNotesActor = HackersPub.ActorNotesQuery.Data.ActorByHandle
private typealias ActorProfileNoteNode = ActorProfileNotesActor.Notes.Edge.Node
private typealias ActorProfileArticlesActor = HackersPub.ActorArticlesQuery.Data.ActorByHandle
private typealias ActorProfileArticleNode = ActorProfileArticlesActor.Articles.Edge.Node

private enum ActorProfilePageApplication {
    case replace
    case prepend
    case append
}

private struct ActorProfilePageQuery {
    let after: GraphQLNullable<String>
    let before: GraphQLNullable<String>
    let first: GraphQLNullable<Int32>
    let last: GraphQLNullable<Int32>
}

extension ActorProfileView {
    func loadInitialNotes(
        cachePolicy: CachePolicy.Query.SingleResponse
    ) async {
        await loadNotesPage(
            kind: .initial,
            pageQuery: ActorProfilePageQuery(after: nil, before: nil, first: 20, last: nil),
            cachePolicy: cachePolicy,
            application: .replace
        )
    }

    func loadMoreNotes() async {
        guard notesPageState.hasNextPage,
              let cursor = notesPageState.endCursor
        else {
            return
        }
        await loadNotesPage(
            kind: .older,
            pageQuery: ActorProfilePageQuery(after: .some(cursor), before: nil, first: 20, last: nil),
            cachePolicy: .networkOnly,
            application: .append
        )
    }

    func loadNewerNotes() async {
        guard let cursor = notesPageState.startCursor else {
            return
        }
        await loadNotesPage(
            kind: .newer,
            pageQuery: ActorProfilePageQuery(after: nil, before: .some(cursor), first: nil, last: 20),
            cachePolicy: .networkOnly,
            application: .prepend
        )
    }

    func refreshNotes() async {
        switch ActorProfileTabRefreshPlan.resolve(
            itemCount: notes.count,
            startCursor: notesPageState.startCursor
        ) {
        case .firstPage:
            await loadNotesPage(
                kind: .refresh,
                pageQuery: ActorProfilePageQuery(after: nil, before: nil, first: 20, last: nil),
                cachePolicy: .networkOnly,
                application: .replace
            )
        case let .newer(cursor):
            await loadNotesPage(
                kind: .refresh,
                pageQuery: ActorProfilePageQuery(after: nil, before: .some(cursor), first: nil, last: 20),
                cachePolicy: .networkOnly,
                application: .prepend
            )
        }
    }

    func loadInitialArticles(
        cachePolicy: CachePolicy.Query.SingleResponse
    ) async {
        await loadArticlesPage(
            kind: .initial,
            pageQuery: ActorProfilePageQuery(after: nil, before: nil, first: 20, last: nil),
            cachePolicy: cachePolicy,
            application: .replace
        )
    }

    func loadMoreArticles() async {
        guard articlesPageState.hasNextPage,
              let cursor = articlesPageState.endCursor
        else {
            return
        }
        await loadArticlesPage(
            kind: .older,
            pageQuery: ActorProfilePageQuery(after: .some(cursor), before: nil, first: 20, last: nil),
            cachePolicy: .networkOnly,
            application: .append
        )
    }

    func loadNewerArticles() async {
        guard let cursor = articlesPageState.startCursor else {
            return
        }
        await loadArticlesPage(
            kind: .newer,
            pageQuery: ActorProfilePageQuery(after: nil, before: .some(cursor), first: nil, last: 20),
            cachePolicy: .networkOnly,
            application: .prepend
        )
    }

    func refreshArticles() async {
        switch ActorProfileTabRefreshPlan.resolve(
            itemCount: articles.count,
            startCursor: articlesPageState.startCursor
        ) {
        case .firstPage:
            await loadArticlesPage(
                kind: .refresh,
                pageQuery: ActorProfilePageQuery(after: nil, before: nil, first: 20, last: nil),
                cachePolicy: .networkOnly,
                application: .replace
            )
        case let .newer(cursor):
            await loadArticlesPage(
                kind: .refresh,
                pageQuery: ActorProfilePageQuery(after: nil, before: .some(cursor), first: nil, last: 20),
                cachePolicy: .networkOnly,
                application: .prepend
            )
        }
    }

    private func loadNotesPage(
        kind: ActorProfileTabRequestKind,
        pageQuery: ActorProfilePageQuery,
        cachePolicy: CachePolicy.Query.SingleResponse,
        application: ActorProfilePageApplication
    ) async {
        guard let request = notesRequestCoordinator.begin(kind) else {
            return
        }

        notesPageState.isLoading = true
        defer {
            if notesRequestCoordinator.finish(request) {
                notesPageState.isLoading = false
            }
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorNotesQuery(
                    handle: actorData.handle,
                    after: pageQuery.after,
                    before: pageQuery.before,
                    first: pageQuery.first,
                    last: pageQuery.last
                ),
                cachePolicy: cachePolicy
            )
            try Task.checkCancellation()
            guard notesRequestCoordinator.isCurrent(request),
                  let actor = try notesActor(from: response, for: request)
            else {
                return
            }
            applyNotes(actor.notes, application: application)
        } catch is CancellationError {
            return
        } catch {
            guard notesRequestCoordinator.isCurrent(request) else {
                return
            }
            notesPageState.errorMessage = error.localizedDescription
        }
    }

    private func loadArticlesPage(
        kind: ActorProfileTabRequestKind,
        pageQuery: ActorProfilePageQuery,
        cachePolicy: CachePolicy.Query.SingleResponse,
        application: ActorProfilePageApplication
    ) async {
        guard let request = articlesRequestCoordinator.begin(kind) else {
            return
        }

        articlesPageState.isLoading = true
        defer {
            if articlesRequestCoordinator.finish(request) {
                articlesPageState.isLoading = false
            }
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorArticlesQuery(
                    handle: actorData.handle,
                    after: pageQuery.after,
                    before: pageQuery.before,
                    first: pageQuery.first,
                    last: pageQuery.last
                ),
                cachePolicy: cachePolicy
            )
            try Task.checkCancellation()
            guard articlesRequestCoordinator.isCurrent(request),
                  let actor = try articlesActor(from: response, for: request)
            else {
                return
            }
            applyArticles(actor.articles, application: application)
        } catch is CancellationError {
            return
        } catch {
            guard articlesRequestCoordinator.isCurrent(request) else {
                return
            }
            articlesPageState.errorMessage = error.localizedDescription
        }
    }

    private func notesActor(
        from response: GraphQLResponse<HackersPub.ActorNotesQuery>,
        for request: ActorProfileTabRequest
    ) throws -> ActorProfileNotesActor? {
        guard notesRequestCoordinator.isCurrent(request) else {
            return nil
        }
        if let error = response.errors?.first {
            throw error
        }
        guard let actor = response.data?.actorByHandle else {
            throw ActorRelationshipServiceError.actorNotFound
        }
        guard actor.id == request.actorID else {
            return nil
        }
        return actor
    }

    private func articlesActor(
        from response: GraphQLResponse<HackersPub.ActorArticlesQuery>,
        for request: ActorProfileTabRequest
    ) throws -> ActorProfileArticlesActor? {
        guard articlesRequestCoordinator.isCurrent(request) else {
            return nil
        }
        if let error = response.errors?.first {
            throw error
        }
        guard let actor = response.data?.actorByHandle else {
            throw ActorRelationshipServiceError.actorNotFound
        }
        guard actor.id == request.actorID else {
            return nil
        }
        return actor
    }

    private func applyNotes(
        _ connection: ActorProfileNotesActor.Notes,
        application: ActorProfilePageApplication
    ) {
        let incoming = connection.edges.map(\.node)
        switch application {
        case .replace:
            notes = incoming
            applyFirstPageInfo(connection.pageInfo, to: &notesPageState)
        case .prepend:
            let previousStartCursor = notesPageState.startCursor
            let prependedCount = prependUniqueNotes(incoming)
            applyPrependPageInfo(
                connection.pageInfo,
                previousStartCursor: previousStartCursor,
                prependedCount: prependedCount,
                to: &notesPageState
            )
        case .append:
            let appendedCount = appendUniqueNotes(incoming)
            _ = notesPageState.applyLoadMorePage(
                appendedCount: appendedCount,
                nextEndCursor: connection.pageInfo.endCursor,
                hasNextPage: connection.pageInfo.hasNextPage
            )
        }
    }

    private func applyArticles(
        _ connection: ActorProfileArticlesActor.Articles,
        application: ActorProfilePageApplication
    ) {
        let incoming = connection.edges.map(\.node)
        switch application {
        case .replace:
            articles = incoming
            applyFirstPageInfo(connection.pageInfo, to: &articlesPageState)
        case .prepend:
            let previousStartCursor = articlesPageState.startCursor
            let prependedCount = prependUniqueArticles(incoming)
            applyPrependPageInfo(
                connection.pageInfo,
                previousStartCursor: previousStartCursor,
                prependedCount: prependedCount,
                to: &articlesPageState
            )
        case .append:
            let appendedCount = appendUniqueArticles(incoming)
            _ = articlesPageState.applyLoadMorePage(
                appendedCount: appendedCount,
                nextEndCursor: connection.pageInfo.endCursor,
                hasNextPage: connection.pageInfo.hasNextPage
            )
        }
    }

    private func applyFirstPageInfo(
        _ pageInfo: some ActorProfilePageInfo,
        to pageState: inout ActorProfileTabPageState
    ) {
        pageState.hasLoaded = true
        pageState.hasPreviousPage = pageInfo.hasPreviousPage
        pageState.hasNextPage = pageInfo.hasNextPage
        pageState.startCursor = pageInfo.startCursor
        pageState.endCursor = pageInfo.endCursor
        pageState.errorMessage = nil
    }

    private func applyPrependPageInfo(
        _ pageInfo: some ActorProfilePageInfo,
        previousStartCursor: String?,
        prependedCount: Int,
        to pageState: inout ActorProfileTabPageState
    ) {
        let nextStartCursor = pageInfo.startCursor
        pageState.hasLoaded = true
        pageState.hasPreviousPage = prependedCount > 0 || nextStartCursor != previousStartCursor
            ? pageInfo.hasPreviousPage
            : false
        if let nextStartCursor {
            pageState.startCursor = nextStartCursor
        }
        if pageState.endCursor == nil {
            pageState.endCursor = pageInfo.endCursor
        }
        pageState.errorMessage = nil
    }

    @discardableResult
    private func prependUniqueNotes(_ incoming: [ActorProfileNoteNode]) -> Int {
        let existingIDs = Set(notes.map(\.id))
        let unique = incoming.filter { !existingIDs.contains($0.id) }
        notes = unique + notes
        return unique.count
    }

    @discardableResult
    private func appendUniqueNotes(_ incoming: [ActorProfileNoteNode]) -> Int {
        let existingIDs = Set(notes.map(\.id))
        let unique = incoming.filter { !existingIDs.contains($0.id) }
        notes.append(contentsOf: unique)
        return unique.count
    }

    @discardableResult
    private func prependUniqueArticles(_ incoming: [ActorProfileArticleNode]) -> Int {
        let existingIDs = Set(articles.map(\.id))
        let unique = incoming.filter { !existingIDs.contains($0.id) }
        articles = unique + articles
        return unique.count
    }

    @discardableResult
    private func appendUniqueArticles(_ incoming: [ActorProfileArticleNode]) -> Int {
        let existingIDs = Set(articles.map(\.id))
        let unique = incoming.filter { !existingIDs.contains($0.id) }
        articles.append(contentsOf: unique)
        return unique.count
    }
}
