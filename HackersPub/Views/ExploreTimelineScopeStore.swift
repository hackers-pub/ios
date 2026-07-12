import Foundation
import Observation

struct ExploreTimelineRequest: Equatable {
    enum Operation: Equatable {
        case initial
        case older(String)
        case newer(String)
    }

    let generation: Int
    let operation: Operation
}

enum ExploreTimelinePostContentEventResult: Equatable {
    case ignored
    case applied(replay: ExploreTimelineRequest?)

    var replay: ExploreTimelineRequest? {
        guard case let .applied(replay) = self else { return nil }
        return replay
    }
}

/// Presentation state for one Explore scope. The view owns request scheduling,
/// while this store serializes work and invalidates stale completions.
@Observable
@MainActor
final class ExploreTimelineScopeStore<Edge: ExploreTimelineEdge> {
    private(set) var edges: [Edge] = []
    private(set) var hasLoadedInitial = false
    private(set) var errorMessage: String?
    private(set) var hasPreviousPage = false
    private(set) var hasNextPage = false
    private(set) var startCursor: String?
    private(set) var endCursor: String?
    private(set) var pendingNewerCursor: String?
    private var activeRequest: ExploreTimelineRequest?
    private var nextGeneration = 0
    private var refreshReplayPending = false
    private var deletedPostIDs: Set<String> = []

    var isLoading: Bool {
        activeRequest != nil
    }

    var isLoadingInitial: Bool {
        if case .initial? = activeRequest?.operation {
            return true
        }
        return false
    }

    var isLoadingOlder: Bool {
        if case .older? = activeRequest?.operation {
            return true
        }
        return false
    }

    var isLoadingNewer: Bool {
        if case .newer? = activeRequest?.operation {
            return true
        }
        return false
    }

    /// Measured semantic rows and offsets survive Local/Global scope changes.
    var scrollViewport = FeedViewportSnapshot<String>()

    func startInitialLoadIfNeeded() -> ExploreTimelineRequest? {
        guard !hasLoadedInitial, activeRequest == nil else { return nil }
        return begin(.initial)
    }

    func requestRefresh() -> ExploreTimelineRequest? {
        guard activeRequest == nil else {
            refreshReplayPending = true
            return nil
        }

        return beginRefresh()
    }

    func requestOlderPage() -> ExploreTimelineRequest? {
        guard activeRequest == nil,
              let endCursor,
              hasNextPage
        else {
            return nil
        }

        return begin(.older(endCursor))
    }

    func requestNewerPage() -> ExploreTimelineRequest? {
        guard activeRequest == nil,
              let cursor = pendingNewerCursor ?? startCursor
        else {
            return nil
        }

        return begin(.newer(cursor))
    }

    func isCurrent(_ request: ExploreTimelineRequest) -> Bool {
        activeRequest == request
    }

    func resolve(
        _ request: ExploreTimelineRequest,
        with result: Result<ExploreTimelineFetchResult<Edge>, Error>
    ) -> ExploreTimelineRequest? {
        guard activeRequest == request else { return nil }

        activeRequest = nil

        switch result {
        case let .success(response):
            apply(response, for: request.operation)
        case let .failure(error) where error is CancellationError:
            break
        case let .failure(error):
            record(error: error)
        }

        return beginPendingRefreshReplayIfNeeded()
    }

    func applyPostContentEvent(_ event: PostContentEvent) -> ExploreTimelinePostContentEventResult {
        guard case let .postDeleted(postID) = event else { return .ignored }
        deletedPostIDs.insert(postID)

        let action = PostContentListEventRouter.route(
            event,
            host: .explore,
            rows: edges.map(\.postContentListIdentity),
            eventGeneration: nextGeneration,
            activeGeneration: nextGeneration
        )
        if case let .remove(rowIDs) = action {
            let removedRowIDs = Set(rowIDs)
            edges.removeAll { removedRowIDs.contains($0.postContentListIdentity.rowID) }
        }

        // A non-cooperative request must not restore a deleted row after its task is cancelled.
        if activeRequest != nil {
            refreshReplayPending = true
        }
        nextGeneration &+= 1
        activeRequest = nil

        return .applied(replay: beginPendingRefreshReplayIfNeeded())
    }

    /// Scope changes cancel the visible task. Bumping the generation makes any
    /// non-cooperative network completion a harmless stale result.
    func cancelVisibleWork() {
        activeRequest = nil
        refreshReplayPending = false
        nextGeneration &+= 1
    }

    func replaceInitial(with page: ExploreTimelinePage<Edge>) {
        edges = unique(page.edges, excluding: [])
        hasPreviousPage = false
        pendingNewerCursor = nil
        hasNextPage = page.pageInfo.hasNextPage
        startCursor = page.pageInfo.startCursor
        endCursor = page.pageInfo.endCursor
        errorMessage = nil
    }

    func appendOlder(_ page: ExploreTimelinePage<Edge>) {
        edges.append(contentsOf: unique(page.edges, excluding: Set(edges.map(\.timelineListID))))
        hasNextPage = page.pageInfo.hasNextPage
        endCursor = page.pageInfo.endCursor
        errorMessage = nil
    }

    func mergeNewer(_ page: ExploreTimelinePage<Edge>) {
        guard !page.edges.isEmpty else {
            hasPreviousPage = false
            pendingNewerCursor = nil
            return
        }

        let incoming = unique(page.edges, excluding: Set(edges.map(\.timelineListID)))
        edges = incoming + edges
        pendingNewerCursor = page.pageInfo.hasPreviousPage ? page.pageInfo.startCursor : nil
        hasPreviousPage = page.pageInfo.hasPreviousPage && page.pageInfo.startCursor != nil
        startCursor = edges.first?.cursor
        if endCursor == nil {
            endCursor = page.pageInfo.endCursor
        }
        errorMessage = nil
    }

    func record(error: Error) {
        errorMessage = error.localizedDescription
    }

    private func begin(_ operation: ExploreTimelineRequest.Operation) -> ExploreTimelineRequest {
        nextGeneration &+= 1
        let request = ExploreTimelineRequest(generation: nextGeneration, operation: operation)
        activeRequest = request
        return request
    }

    private func beginRefresh() -> ExploreTimelineRequest {
        guard let startCursor else { return begin(.initial) }

        // A local deletion can leave the timeline empty while its cursor remains valid.
        return begin(.newer(pendingNewerCursor ?? startCursor))
    }

    private func beginPendingRefreshReplayIfNeeded() -> ExploreTimelineRequest? {
        guard refreshReplayPending else { return nil }
        refreshReplayPending = false
        return beginRefresh()
    }

    private func apply(
        _ response: ExploreTimelineFetchResult<Edge>,
        for operation: ExploreTimelineRequest.Operation
    ) {
        guard let page = response.page else {
            errorMessage = response.errorMessage ?? NSLocalizedString(
                "explore.error.noData",
                comment: "Explore timeline response without data"
            )
            return
        }
        let filteredPage = filteringDeletedPosts(from: page)

        switch operation {
        case .initial:
            replaceInitial(with: filteredPage)
            hasLoadedInitial = true
        case .older:
            appendOlder(filteredPage)
        case .newer:
            mergeNewer(filteredPage)
        }
        errorMessage = response.errorMessage
    }

    private func filteringDeletedPosts(
        from page: ExploreTimelinePage<Edge>
    ) -> ExploreTimelinePage<Edge> {
        ExploreTimelinePage(
            edges: page.edges.filter { edge in
                let identity = edge.postContentListIdentity
                guard !deletedPostIDs.contains(identity.postID) else { return false }
                return identity.displayedPostID.map { !deletedPostIDs.contains($0) } ?? true
            },
            pageInfo: page.pageInfo
        )
    }

    private func unique(_ incoming: [Edge], excluding knownIDs: Set<String>) -> [Edge] {
        var seenIDs = knownIDs
        return incoming.filter { edge in
            seenIDs.insert(edge.timelineListID).inserted
        }
    }
}
