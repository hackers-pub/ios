import Foundation

@MainActor
struct TimelineRefreshCoordinator<Edge> {
    typealias FetchPage = (_ cursor: String?, _ pageSize: Int) async throws -> TimelineRefreshPage<Edge>

    private let pageSize: Int
    private let identifier: (Edge) -> String
    private let limits: TimelineRefreshLimits
    private let partialFailureMessage: String
    private let fetchPage: FetchPage

    init(
        pageSize: Int,
        identifier: @escaping (Edge) -> String,
        limits: TimelineRefreshLimits = .production,
        partialFailureMessage: String = TimelineRefreshWarning.localizedMessage,
        fetchPage: @escaping FetchPage
    ) {
        self.pageSize = pageSize
        self.identifier = identifier
        self.limits = limits
        self.partialFailureMessage = partialFailureMessage
        self.fetchPage = fetchPage
    }

    func load(targetCount: Int) async throws -> TimelineRefreshSnapshot<Edge> {
        let minimumCount = max(targetCount, 1)
        var progress = TimelineRefreshProgress<Edge>()

        while true {
            let page: TimelineRefreshPage<Edge>
            do {
                try Task.checkCancellation()
                page = try await fetchPage(progress.requestedCursor, pageSize)
                try Task.checkCancellation()
            } catch {
                return try recover(from: error, progress: progress)
            }

            let pageResult = progress.ingest(
                page,
                identifier: identifier,
                maxUniqueRows: limits.maxUniqueRows
            )

            switch decision(after: pageResult, progress: progress, minimumCount: minimumCount) {
            case .complete:
                return progress.snapshot(
                    completeness: progress.warning.map(TimelineRefreshCompleteness.partial) ?? .authoritative
                )
            case let .next(cursor):
                progress.advance(to: cursor)
            case let .partial(reason, debugMessage):
                return progress.partialSnapshot(
                    reason: reason,
                    message: partialFailureMessage,
                    debugMessage: debugMessage
                )
            }
        }
    }

    private func recover(
        from error: Error,
        progress: TimelineRefreshProgress<Edge>
    ) throws -> TimelineRefreshSnapshot<Edge> {
        if isRefreshCancellation(error) {
            throw error
        }
        guard progress.hasFetchedPage else { throw error }

        let debugMessage = (error as? TimelineRefreshError)?.debugMessage
            ?? error.localizedDescription
        return progress.partialSnapshot(
            reason: .laterPageFailure,
            message: partialFailureMessage,
            debugMessage: debugMessage
        )
    }

    private func decision(
        after page: TimelineRefreshPageResult,
        progress: TimelineRefreshProgress<Edge>,
        minimumCount: Int
    ) -> TimelineRefreshDecision {
        if page.truncated {
            return .partial(
                .uniqueRowLimitReached,
                "Refresh page exceeded the \(limits.maxUniqueRows)-row budget."
            )
        }
        guard progress.edges.count < minimumCount, progress.hasNextPage else {
            return .complete
        }
        if progress.edges.count >= limits.maxUniqueRows {
            return .partial(
                .uniqueRowLimitReached,
                "Refresh reached the \(limits.maxUniqueRows)-row budget."
            )
        }
        if progress.fetchedPageCount >= limits.maxPages {
            return .partial(
                .pageLimitReached,
                "Refresh reached the \(limits.maxPages)-page budget."
            )
        }
        guard page.cursorProgresses, let nextCursor = page.nextCursor else {
            return .partial(.noProgress, "Refresh cursor did not advance.")
        }
        if progress.consecutiveNoProgressPages >= limits.maxConsecutiveNoProgressPages {
            return .partial(
                .noProgress,
                "Refresh produced no unique rows for \(progress.consecutiveNoProgressPages) consecutive pages."
            )
        }
        return .next(nextCursor)
    }

    private func isRefreshCancellation(_ error: Error) -> Bool {
        if error is CancellationError || Task.isCancelled {
            return true
        }
        guard let urlError = error as? URLError else { return false }
        return urlError.code == .cancelled
    }
}

private struct TimelineRefreshProgress<Edge> {
    private(set) var edges: [Edge] = []
    private(set) var requestedCursor: String?
    private(set) var fetchedPageCount = 0
    private(set) var consecutiveNoProgressPages = 0
    private(set) var hasNextPage = false
    private(set) var warning: TimelineRefreshWarning?

    private var identifiers = Set<String>()
    private var visitedCursors = Set<String>()
    private var firstStartCursor: String?
    private var finalEndCursor: String?

    var hasFetchedPage: Bool {
        fetchedPageCount > 0
    }

    mutating func ingest(
        _ page: TimelineRefreshPage<Edge>,
        identifier: (Edge) -> String,
        maxUniqueRows: Int
    ) -> TimelineRefreshPageResult {
        fetchedPageCount += 1
        if fetchedPageCount == 1 {
            firstStartCursor = page.pageInfo.startCursor
        }
        finalEndCursor = page.pageInfo.endCursor
        warning = warning ?? page.warning

        let insertion = insertUniqueEdges(
            page.edges,
            identifier: identifier,
            maxUniqueRows: maxUniqueRows
        )
        consecutiveNoProgressPages = insertion.insertedCount == 0
            ? consecutiveNoProgressPages + 1
            : 0
        hasNextPage = insertion.truncated || page.pageInfo.hasNextPage

        let nextCursor = page.pageInfo.endCursor
        let cursorProgresses = nextCursor.map {
            $0 != requestedCursor && !visitedCursors.contains($0)
        } ?? false
        return TimelineRefreshPageResult(
            nextCursor: nextCursor,
            cursorProgresses: cursorProgresses,
            truncated: insertion.truncated
        )
    }

    mutating func advance(to cursor: String) {
        visitedCursors.insert(cursor)
        requestedCursor = cursor
    }

    func snapshot(completeness: TimelineRefreshCompleteness) -> TimelineRefreshSnapshot<Edge> {
        TimelineRefreshSnapshot(
            edges: edges,
            pageInfo: TimelinePageInfo(
                hasPreviousPage: false,
                hasNextPage: hasNextPage,
                startCursor: firstStartCursor,
                endCursor: finalEndCursor
            ),
            completeness: completeness
        )
    }

    func partialSnapshot(
        reason: TimelineRefreshWarning.Reason,
        message: String,
        debugMessage: String
    ) -> TimelineRefreshSnapshot<Edge> {
        snapshot(
            completeness: .partial(
                TimelineRefreshWarning(
                    reason: reason,
                    message: message,
                    debugMessage: debugMessage
                )
            )
        )
    }

    private mutating func insertUniqueEdges(
        _ incoming: [Edge],
        identifier: (Edge) -> String,
        maxUniqueRows: Int
    ) -> TimelineRefreshInsertion {
        var insertedCount = 0

        for edge in incoming {
            let edgeIdentifier = identifier(edge)
            guard !identifiers.contains(edgeIdentifier) else { continue }
            guard edges.count < maxUniqueRows else {
                return TimelineRefreshInsertion(insertedCount: insertedCount, truncated: true)
            }

            identifiers.insert(edgeIdentifier)
            edges.append(edge)
            insertedCount += 1
        }

        return TimelineRefreshInsertion(insertedCount: insertedCount, truncated: false)
    }
}

private struct TimelineRefreshPageResult {
    let nextCursor: String?
    let cursorProgresses: Bool
    let truncated: Bool
}

private struct TimelineRefreshInsertion {
    let insertedCount: Int
    let truncated: Bool
}

private enum TimelineRefreshDecision {
    case complete
    case next(String)
    case partial(TimelineRefreshWarning.Reason, String)
}
