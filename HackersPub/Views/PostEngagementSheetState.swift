@preconcurrency import Apollo
import Foundation
import Observation

struct EngagementListPage<Item> {
    let items: [Item]
    let hasMore: Bool
    let endCursor: String?
}

enum EngagementListLoadFailure: Error, Equatable {
    case graphQL(String)
    case missingData
    case transport(String)
    case cancelled

    var message: String? {
        switch self {
        case let .graphQL(message), let .transport(message):
            return message
        case .missingData:
            return PostEngagementSheetL10n.invalidResponse
        case .cancelled:
            return nil
        }
    }
}

@MainActor
@Observable
final class EngagementListSheetState<Item> {
    typealias Loader = (String?) async -> Result<EngagementListPage<Item>, EngagementListLoadFailure>

    private let itemID: (Item) -> String
    private var loader: Loader
    private var generation = 0
    private var visitedCursors: Set<String> = []
    private var initialLoadTask: Task<Result<EngagementListPage<Item>, EngagementListLoadFailure>, Never>?
    private var loadMoreTask: Task<Result<EngagementListPage<Item>, EngagementListLoadFailure>, Never>?

    private(set) var items: [Item] = []
    private(set) var cursor: String?
    private(set) var hasMore = false
    private(set) var isLoadingInitial = false
    private(set) var isLoadingMore = false
    private(set) var hasAttemptedInitialLoad = false
    private(set) var initialErrorMessage: String?
    private(set) var paginationErrorMessage: String?

    init(id itemID: @escaping (Item) -> String, loader: @escaping Loader) {
        self.itemID = itemID
        self.loader = loader
    }

    var showsInitialFailure: Bool {
        hasAttemptedInitialLoad && items.isEmpty && !isLoadingInitial && initialErrorMessage != nil
    }

    func loadInitialIfNeeded() async {
        guard !hasAttemptedInitialLoad, !isLoadingInitial else { return }
        await reload()
    }

    func reload() async {
        initialLoadTask?.cancel()
        loadMoreTask?.cancel()
        generation += 1
        let requestGeneration = generation

        hasAttemptedInitialLoad = true
        isLoadingInitial = true
        isLoadingMore = false
        initialErrorMessage = nil
        paginationErrorMessage = nil

        let task = Task { [loader] in
            await loader(nil)
        }
        initialLoadTask = task
        let result = await task.value
        guard requestGeneration == generation else { return }
        initialLoadTask = nil
        finishInitialLoad(requestGeneration: requestGeneration, result: result)
    }

    func retryInitial() async {
        await reload()
    }

    func loadMore() async {
        guard !isLoadingInitial,
              !isLoadingMore,
              hasMore,
              let requestedCursor = cursor
        else {
            return
        }

        guard !visitedCursors.contains(requestedCursor) else {
            stopPagination()
            return
        }

        let requestGeneration = generation
        isLoadingMore = true
        paginationErrorMessage = nil

        let task = Task { [loader] in
            await loader(requestedCursor)
        }
        loadMoreTask = task
        let result = await task.value
        guard requestGeneration == generation else { return }
        loadMoreTask = nil
        finishLoadMore(
            requestGeneration: requestGeneration,
            requestedCursor: requestedCursor,
            result: result
        )
    }

    func retryLoadMore() async {
        await loadMore()
    }

    func retryVisibleError() async {
        if paginationErrorMessage != nil {
            await retryLoadMore()
        } else {
            await retryInitial()
        }
    }

    func cancelPendingLoads() {
        initialLoadTask?.cancel()
        loadMoreTask?.cancel()
        initialLoadTask = nil
        loadMoreTask = nil
        generation += 1
        isLoadingInitial = false
        isLoadingMore = false
    }

    func reset(loader: @escaping Loader) {
        cancelPendingLoads()
        self.loader = loader
        visitedCursors.removeAll()
        items.removeAll()
        cursor = nil
        hasMore = false
        hasAttemptedInitialLoad = false
        initialErrorMessage = nil
        paginationErrorMessage = nil
    }

    private func finishInitialLoad(
        requestGeneration: Int,
        result: Result<EngagementListPage<Item>, EngagementListLoadFailure>
    ) {
        guard requestGeneration == generation else { return }

        isLoadingInitial = false
        guard !Task.isCancelled else { return }

        switch result {
        case let .success(page):
            items = uniqueItems(from: page.items)
            visitedCursors.removeAll()
            initialErrorMessage = nil
            paginationErrorMessage = nil
            updatePagination(from: page, after: nil)
        case let .failure(failure):
            initialErrorMessage = failure.message
        }
    }

    private func finishLoadMore(
        requestGeneration: Int,
        requestedCursor: String,
        result: Result<EngagementListPage<Item>, EngagementListLoadFailure>
    ) {
        guard requestGeneration == generation else { return }

        isLoadingMore = false
        guard !Task.isCancelled else { return }

        switch result {
        case let .success(page):
            visitedCursors.insert(requestedCursor)
            appendUniqueItems(page.items)
            paginationErrorMessage = nil
            updatePagination(from: page, after: requestedCursor)
        case let .failure(failure):
            paginationErrorMessage = failure.message
        }
    }

    private func updatePagination(from page: EngagementListPage<Item>, after requestedCursor: String?) {
        guard page.hasMore,
              let nextCursor = page.endCursor,
              !nextCursor.isEmpty,
              nextCursor != requestedCursor,
              !visitedCursors.contains(nextCursor)
        else {
            stopPagination()
            return
        }

        hasMore = true
        cursor = nextCursor
    }

    private func stopPagination() {
        hasMore = false
        cursor = nil
    }

    private func uniqueItems(from candidates: [Item]) -> [Item] {
        var seenIDs: Set<String> = []
        return candidates.filter { candidate in
            seenIDs.insert(itemID(candidate)).inserted
        }
    }

    private func appendUniqueItems(_ candidates: [Item]) {
        var seenIDs = Set(items.map(itemID))
        items.append(contentsOf: candidates.filter { candidate in
            seenIDs.insert(itemID(candidate)).inserted
        })
    }
}

@MainActor
enum PostEngagementSheetLoader {
    typealias Quote = HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node

    static func shares(
        postID: String,
        after cursor: String?
    ) async -> Result<EngagementListPage<ShareActorInfo>, EngagementListLoadFailure> {
        do {
            let query = HackersPub.PostSharesQuery(
                id: postID,
                after: cursor.map { .some($0) } ?? nil
            )
            let response = try await apolloClient.fetch(query: query)

            if let error = response.errors?.first {
                return .failure(.graphQL(error.message ?? PostEngagementSheetL10n.invalidResponse))
            }

            guard let shares = response.data?.node?.asPost?.shares else {
                return .failure(.missingData)
            }

            return .success(
                EngagementListPage(
                    items: shares.edges.map { edge in
                        ShareActorInfo(
                            id: edge.node.actor.id,
                            name: edge.node.actor.name,
                            handle: edge.node.actor.handle,
                            avatarUrl: edge.node.actor.avatarUrl
                        )
                    },
                    hasMore: shares.pageInfo.hasNextPage,
                    endCursor: shares.pageInfo.endCursor
                )
            )
        } catch is CancellationError {
            return .failure(.cancelled)
        } catch {
            return .failure(.transport(error.localizedDescription))
        }
    }

    static func quotes(
        postID: String,
        after cursor: String?
    ) async -> Result<EngagementListPage<Quote>, EngagementListLoadFailure> {
        do {
            let query = HackersPub.PostQuotesQuery(
                id: postID,
                after: cursor.map { .some($0) } ?? nil
            )
            let response = try await apolloClient.fetch(query: query)

            if let error = response.errors?.first {
                return .failure(.graphQL(error.message ?? PostEngagementSheetL10n.invalidResponse))
            }

            guard let quotes = response.data?.node?.asPost?.quotes else {
                return .failure(.missingData)
            }

            return .success(
                EngagementListPage(
                    items: quotes.edges.map(\.node),
                    hasMore: quotes.pageInfo.hasNextPage,
                    endCursor: quotes.pageInfo.endCursor
                )
            )
        } catch is CancellationError {
            return .failure(.cancelled)
        } catch {
            return .failure(.transport(error.localizedDescription))
        }
    }
}

enum PostEngagementSheetL10n {
    static let sharesTitle = NSLocalizedString("engagement.shares.title", comment: "Shares sheet title")
    static let quotesTitle = NSLocalizedString("engagement.quotes.title", comment: "Quotes sheet title")
    static let sharesEmpty = NSLocalizedString("engagement.shares.empty", comment: "Shares sheet empty title")
    static let quotesEmpty = NSLocalizedString("engagement.quotes.empty", comment: "Quotes sheet empty title")
    static let sharesLoadMore = NSLocalizedString("engagement.shares.loadMore", comment: "Load more shares")
    static let quotesLoadMore = NSLocalizedString("engagement.quotes.loadMore", comment: "Load more quotes")
    static let retry = NSLocalizedString("common.retry", comment: "Retry")
    static let paginationFailure = NSLocalizedString(
        "engagement.pagination.failure",
        comment: "Pagination failure title"
    )
    static let invalidResponse = NSLocalizedString(
        "engagement.error.invalidResponse",
        comment: "Engagement response missing data"
    )
}
