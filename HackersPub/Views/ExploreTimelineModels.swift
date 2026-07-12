@preconcurrency import Apollo
import Foundation

typealias LocalExploreTimelineEdge = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge
typealias GlobalExploreTimelineEdge = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge

protocol ExploreTimelineEdge {
    var cursor: String { get }
    var timelineListID: String { get }
    var postContentListIdentity: PostListItemIdentity { get }
}

extension LocalExploreTimelineEdge: ExploreTimelineEdge {
    var postContentListIdentity: PostListItemIdentity {
        PostListItemIdentity(
            rowID: timelineListID,
            postID: node.id,
            displayedPostID: node.sharedPost?.id
        )
    }
}

extension GlobalExploreTimelineEdge: ExploreTimelineEdge {
    var postContentListIdentity: PostListItemIdentity {
        PostListItemIdentity(
            rowID: timelineListID,
            postID: node.id,
            displayedPostID: node.sharedPost?.id
        )
    }
}

struct ExploreTimelinePageInfo {
    let hasPreviousPage: Bool
    let hasNextPage: Bool
    let startCursor: String?
    let endCursor: String?
}

struct ExploreTimelinePage<Edge> {
    let edges: [Edge]
    let pageInfo: ExploreTimelinePageInfo
}

struct ExploreTimelineFetchResult<Edge> {
    let page: ExploreTimelinePage<Edge>?
    let errorMessage: String?
}

struct ExploreTimelineDataSource<Edge: ExploreTimelineEdge> {
    typealias InitialPageFetcher = @MainActor () async throws -> ExploreTimelineFetchResult<Edge>
    typealias PageFetcher = @MainActor (String) async throws -> ExploreTimelineFetchResult<Edge>

    let fetchInitial: InitialPageFetcher
    let fetchOlder: PageFetcher
    let fetchNewer: PageFetcher
}

extension ExploreTimelineDataSource where Edge == LocalExploreTimelineEdge {
    static var local: Self {
        Self(
            fetchInitial: {
                let responses = try apolloClient.fetch(
                    query: HackersPub.LocalTimelineQuery(after: nil, before: nil, first: 20, last: nil),
                    cachePolicy: .cacheAndNetwork
                )
                return try await collectTimelineResult(from: responses) { data in
                    localTimelinePage(data.publicTimeline)
                }
            },
            fetchOlder: { cursor in
                let responses = try apolloClient.fetch(
                    query: HackersPub.LocalTimelineQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                    cachePolicy: .cacheAndNetwork
                )
                return try await collectTimelineResult(from: responses) { data in
                    localTimelinePage(data.publicTimeline)
                }
            },
            fetchNewer: { cursor in
                let responses = try apolloClient.fetch(
                    query: HackersPub.LocalTimelineQuery(after: nil, before: .some(cursor), first: nil, last: 20),
                    cachePolicy: .cacheAndNetwork
                )
                return try await collectTimelineResult(from: responses) { data in
                    localTimelinePage(data.publicTimeline)
                }
            }
        )
    }
}

extension ExploreTimelineDataSource where Edge == GlobalExploreTimelineEdge {
    static var global: Self {
        Self(
            fetchInitial: {
                let responses = try apolloClient.fetch(
                    query: HackersPub.PublicTimelineQuery(after: nil, before: nil, first: 20, last: nil),
                    cachePolicy: .cacheAndNetwork
                )
                return try await collectTimelineResult(from: responses) { data in
                    globalTimelinePage(data.publicTimeline)
                }
            },
            fetchOlder: { cursor in
                let responses = try apolloClient.fetch(
                    query: HackersPub.PublicTimelineQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                    cachePolicy: .cacheAndNetwork
                )
                return try await collectTimelineResult(from: responses) { data in
                    globalTimelinePage(data.publicTimeline)
                }
            },
            fetchNewer: { cursor in
                let responses = try apolloClient.fetch(
                    query: HackersPub.PublicTimelineQuery(after: nil, before: .some(cursor), first: nil, last: 20),
                    cachePolicy: .cacheAndNetwork
                )
                return try await collectTimelineResult(from: responses) { data in
                    globalTimelinePage(data.publicTimeline)
                }
            }
        )
    }
}

@MainActor
func collectTimelineResult<Query: GraphQLQuery, Edge: ExploreTimelineEdge>(
    from responses: AsyncThrowingStream<GraphQLResponse<Query>, any Error>,
    page makePage: (Query.Data) -> ExploreTimelinePage<Edge>?
) async throws -> ExploreTimelineFetchResult<Edge> {
    var page: ExploreTimelinePage<Edge>?
    var errors: [String] = []

    do {
        for try await response in responses {
            if let responsePage = response.data.flatMap(makePage) {
                page = responsePage
            }
            errors.append(contentsOf: response.errors?.map(\.description) ?? [])
        }
    } catch {
        if error is CancellationError {
            throw error
        }
        guard page != nil else { throw error }

        let message = error.localizedDescription
        errors.append(message.isEmpty ? String(describing: error) : message)
    }

    return ExploreTimelineFetchResult(
        page: page,
        errorMessage: errors.isEmpty ? nil : errors.joined(separator: "\n")
    )
}

private func localTimelinePage(
    _ connection: HackersPub.LocalTimelineQuery.Data.PublicTimeline
) -> ExploreTimelinePage<LocalExploreTimelineEdge> {
    ExploreTimelinePage(
        edges: connection.edges,
        pageInfo: ExploreTimelinePageInfo(
            hasPreviousPage: connection.pageInfo.hasPreviousPage,
            hasNextPage: connection.pageInfo.hasNextPage,
            startCursor: connection.pageInfo.startCursor,
            endCursor: connection.pageInfo.endCursor
        )
    )
}

private func globalTimelinePage(
    _ connection: HackersPub.PublicTimelineQuery.Data.PublicTimeline
) -> ExploreTimelinePage<GlobalExploreTimelineEdge> {
    ExploreTimelinePage(
        edges: connection.edges,
        pageInfo: ExploreTimelinePageInfo(
            hasPreviousPage: connection.pageInfo.hasPreviousPage,
            hasNextPage: connection.pageInfo.hasNextPage,
            startCursor: connection.pageInfo.startCursor,
            endCursor: connection.pageInfo.endCursor
        )
    )
}
