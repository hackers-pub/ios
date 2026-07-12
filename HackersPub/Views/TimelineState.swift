enum TimelineRequestKind: Equatable, Sendable {
    case initial
    case refresh
    case newer
    case older
}

struct TimelineRequestToken: Equatable, Sendable {
    fileprivate let generation: Int
    fileprivate let kind: TimelineRequestKind
}

enum TimelineRequestOutcome: Equatable, Sendable {
    case success
    case partialSuccess(String)
    case failure(String)
    case cancelled
}

struct TimelinePageInfo: Equatable, Sendable {
    let hasPreviousPage: Bool
    let hasNextPage: Bool
    let startCursor: String?
    let endCursor: String?
}

struct TimelineNewerPage: Equatable, Sendable {
    let nextCursor: String?
    let hasMoreNewer: Bool
    let fallbackEndCursor: String?
}

enum TimelineMergePolicy {
    static func unique<Element>(
        _ items: [Element],
        identifier: (Element) -> String
    ) -> [Element] {
        var identifiers = Set<String>()

        return items.filter { item in
            identifiers.insert(identifier(item)).inserted
        }
    }

    static func prepending<Element>(
        _ incoming: [Element],
        to existing: [Element],
        identifier: (Element) -> String
    ) -> [Element] {
        let uniqueIncoming = unique(incoming, identifier: identifier)
        let incomingIdentifiers = Set(uniqueIncoming.map(identifier))
        let retainedExisting = unique(existing, identifier: identifier)
            .filter { !incomingIdentifiers.contains(identifier($0)) }

        return uniqueIncoming + retainedExisting
    }

    static func appending<Element>(
        _ incoming: [Element],
        to existing: [Element],
        identifier: (Element) -> String
    ) -> [Element] {
        let uniqueExisting = unique(existing, identifier: identifier)
        let existingIdentifiers = Set(uniqueExisting.map(identifier))
        let appended = unique(incoming, identifier: identifier)
            .filter { !existingIdentifiers.contains(identifier($0)) }

        return uniqueExisting + appended
    }

    static func append<Element>(
        _ incoming: [Element],
        to existing: inout [Element],
        identifier: (Element) -> String
    ) {
        var identifiers = Set<String>()
        var retainedCount = 0

        for index in existing.indices {
            let item = existing[index]
            guard identifiers.insert(identifier(item)).inserted else { continue }

            if retainedCount != index {
                existing[retainedCount] = item
            }
            retainedCount += 1
        }
        if retainedCount < existing.count {
            existing.removeSubrange(retainedCount...)
        }

        for item in incoming where identifiers.insert(identifier(item)).inserted {
            existing.append(item)
        }
    }

    static func refreshing<Element>(
        _ incoming: [Element],
        to existing: [Element],
        identifier: (Element) -> String
    ) -> [Element] {
        prepending(incoming, to: existing, identifier: identifier)
    }
}

struct TimelineState<Edge> {
    private(set) var edges: [Edge] = []
    private(set) var hasLoadedInitial = false
    private(set) var isInitialLoading = false
    private(set) var isRefreshing = false
    private(set) var isLoadingNewer = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private(set) var hasPreviousPage = false
    private(set) var hasNextPage = false
    private(set) var startCursor: String?
    private(set) var endCursor: String?
    private(set) var pendingNewerCursor: String?

    private var nextGeneration = 0
    private var activeRequest: TimelineRequestToken?

    var isLoading: Bool {
        isInitialLoading || isRefreshing || isLoadingNewer || isLoadingMore
    }

    var shouldLoadInitial: Bool {
        !hasLoadedInitial && !isLoading
    }

    var canLoadNewer: Bool {
        hasPreviousPage && (pendingNewerCursor ?? startCursor) != nil && !isLoading
    }

    var canLoadMore: Bool {
        hasNextPage && endCursor != nil && !isLoading
    }

    mutating func beginInitial() -> TimelineRequestToken? {
        guard shouldLoadInitial else { return nil }
        return start(.initial)
    }

    mutating func beginRefresh() -> TimelineRequestToken? {
        guard !isLoading else { return nil }
        return start(.refresh)
    }

    mutating func beginNewer() -> TimelineRequestToken? {
        guard canLoadNewer else { return nil }
        return start(.newer)
    }

    mutating func beginMore() -> TimelineRequestToken? {
        guard canLoadMore else { return nil }
        return start(.older)
    }

    func isCurrent(_ request: TimelineRequestToken) -> Bool {
        activeRequest == request
    }

    mutating func discardStaleRequestForNewOwner() {
        guard let activeRequest else { return }

        self.activeRequest = nil
        setLoading(false, for: activeRequest.kind)
        errorMessage = nil
    }

    @discardableResult
    mutating func finish(
        _ request: TimelineRequestToken,
        outcome: TimelineRequestOutcome
    ) -> Bool {
        guard isCurrent(request) else { return false }

        activeRequest = nil
        setLoading(false, for: request.kind)

        switch outcome {
        case .success:
            if request.kind == .initial {
                hasLoadedInitial = true
            }
            errorMessage = nil
        case let .partialSuccess(message):
            if request.kind == .initial {
                hasLoadedInitial = true
            }
            errorMessage = message
        case let .failure(message):
            errorMessage = message
        case .cancelled:
            errorMessage = nil
        }

        return true
    }

    @discardableResult
    mutating func replaceFirstPage(
        _ incoming: [Edge],
        pageInfo: TimelinePageInfo,
        identifier: (Edge) -> String,
        for request: TimelineRequestToken
    ) -> Bool {
        guard isCurrent(request) else { return false }

        edges = TimelineMergePolicy.unique(incoming, identifier: identifier)
        applyFirstPageInfo(pageInfo)
        return true
    }

    @discardableResult
    mutating func mergeRefreshFirstPage(
        _ incoming: [Edge],
        pageInfo: TimelinePageInfo,
        identifier: (Edge) -> String,
        for request: TimelineRequestToken
    ) -> Bool {
        guard isCurrent(request) else { return false }

        edges = TimelineMergePolicy.refreshing(incoming, to: edges, identifier: identifier)
        applyFirstPageInfo(pageInfo)
        return true
    }

    @discardableResult
    mutating func applyRefreshSnapshot(
        _ snapshot: TimelineRefreshSnapshot<Edge>,
        identifier: (Edge) -> String,
        for request: TimelineRequestToken
    ) -> Bool {
        guard isCurrent(request) else { return false }

        if snapshot.isAuthoritative {
            edges = TimelineMergePolicy.unique(snapshot.edges, identifier: identifier)
            applyFirstPageInfo(snapshot.pageInfo)
        } else {
            edges = TimelineMergePolicy.refreshing(snapshot.edges, to: edges, identifier: identifier)
        }
        return true
    }

    @discardableResult
    mutating func appendPage(
        _ incoming: [Edge],
        pageInfo: TimelinePageInfo,
        identifier: (Edge) -> String,
        for request: TimelineRequestToken
    ) -> Bool {
        guard isCurrent(request) else { return false }

        TimelineMergePolicy.append(incoming, to: &edges, identifier: identifier)
        hasNextPage = pageInfo.hasNextPage
        endCursor = pageInfo.endCursor
        return true
    }

    mutating func removeEdges(
        withIdentifiers identifiers: Set<String>,
        identifier: (Edge) -> String
    ) {
        edges.removeAll { identifiers.contains(identifier($0)) }
    }

    @discardableResult
    mutating func mergeNewerPage(
        _ incoming: [Edge],
        page: TimelineNewerPage,
        cursor: (Edge) -> String,
        identifier: (Edge) -> String,
        for request: TimelineRequestToken
    ) -> Bool {
        guard isCurrent(request) else { return false }

        guard !incoming.isEmpty else {
            hasPreviousPage = false
            pendingNewerCursor = nil
            return true
        }

        edges = TimelineMergePolicy.prepending(incoming, to: edges, identifier: identifier)
        pendingNewerCursor = page.hasMoreNewer ? page.nextCursor : nil
        hasPreviousPage = page.hasMoreNewer && page.nextCursor != nil
        startCursor = edges.first.map(cursor)

        if endCursor == nil {
            endCursor = page.fallbackEndCursor
        }

        return true
    }

    private mutating func start(_ kind: TimelineRequestKind) -> TimelineRequestToken {
        nextGeneration += 1
        let request = TimelineRequestToken(
            generation: nextGeneration,
            kind: kind
        )

        activeRequest = request
        errorMessage = nil
        setLoading(true, for: kind)
        return request
    }

    private mutating func setLoading(_ isLoading: Bool, for kind: TimelineRequestKind) {
        switch kind {
        case .initial:
            isInitialLoading = isLoading
        case .refresh:
            isRefreshing = isLoading
        case .newer:
            isLoadingNewer = isLoading
        case .older:
            isLoadingMore = isLoading
        }
    }

    private mutating func applyFirstPageInfo(_ pageInfo: TimelinePageInfo) {
        hasPreviousPage = pageInfo.hasPreviousPage && pageInfo.startCursor != nil
        pendingNewerCursor = nil
        hasNextPage = pageInfo.hasNextPage
        startCursor = pageInfo.startCursor
        endCursor = pageInfo.endCursor
    }
}
