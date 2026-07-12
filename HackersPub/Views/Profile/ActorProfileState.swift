enum ActorProfilePostRequestKind: Equatable, Sendable {
    case initial
    case refresh
    case newer
    case more
}

struct ActorProfilePostRequest: Equatable, Sendable {
    let profileID: String
    let generation: UInt64
    let requestID: UInt64
    let kind: ActorProfilePostRequestKind
}

struct ActorProfilePostRequestCoordinator {
    private(set) var profileID: String
    private(set) var generation: UInt64 = 0
    private(set) var hasLoadedInitial: Bool

    private var nextRequestID: UInt64 = 0
    private var activeInitialRequest: ActorProfilePostRequest?
    private var activeRefreshRequest: ActorProfilePostRequest?
    private var activeNewerRequest: ActorProfilePostRequest?
    private var activeMoreRequest: ActorProfilePostRequest?

    init(profileID: String, hasLoadedInitial: Bool) {
        self.profileID = profileID
        self.hasLoadedInitial = hasLoadedInitial
    }

    mutating func activate(profileID: String, hasLoadedInitial: Bool) -> Bool {
        guard self.profileID != profileID else {
            return false
        }

        self.profileID = profileID
        self.hasLoadedInitial = hasLoadedInitial
        generation &+= 1
        clearActiveRequests()
        return true
    }

    mutating func beginInitialLoadIfNeeded() -> ActorProfilePostRequest? {
        guard !hasLoadedInitial, !hasActiveRequest else {
            return nil
        }
        return begin(.initial)
    }

    mutating func beginRefresh() -> ActorProfilePostRequest? {
        guard activeRefreshRequest == nil else {
            return nil
        }

        generation &+= 1
        clearActiveRequests()
        return begin(.refresh)
    }

    mutating func beginLoadNewer() -> ActorProfilePostRequest? {
        guard !hasActiveRequest else {
            return nil
        }
        return begin(.newer)
    }

    mutating func beginLoadMore() -> ActorProfilePostRequest? {
        guard !hasActiveRequest else {
            return nil
        }
        return begin(.more)
    }

    func isCurrent(_ request: ActorProfilePostRequest) -> Bool {
        request.profileID == profileID
            && request.generation == generation
            && activeRequest(for: request.kind) == request
    }

    @discardableResult
    mutating func finish(
        _ request: ActorProfilePostRequest,
        didLoadInitial: Bool
    ) -> Bool {
        guard isCurrent(request) else {
            return false
        }

        if didLoadInitial {
            hasLoadedInitial = true
        }
        setActiveRequest(nil, for: request.kind)
        return true
    }

    private var hasActiveRequest: Bool {
        activeInitialRequest != nil
            || activeRefreshRequest != nil
            || activeNewerRequest != nil
            || activeMoreRequest != nil
    }

    private mutating func begin(_ kind: ActorProfilePostRequestKind) -> ActorProfilePostRequest {
        nextRequestID &+= 1
        let request = ActorProfilePostRequest(
            profileID: profileID,
            generation: generation,
            requestID: nextRequestID,
            kind: kind
        )
        setActiveRequest(request, for: kind)
        return request
    }

    private func activeRequest(
        for kind: ActorProfilePostRequestKind
    ) -> ActorProfilePostRequest? {
        switch kind {
        case .initial:
            activeInitialRequest
        case .refresh:
            activeRefreshRequest
        case .newer:
            activeNewerRequest
        case .more:
            activeMoreRequest
        }
    }

    private mutating func setActiveRequest(
        _ request: ActorProfilePostRequest?,
        for kind: ActorProfilePostRequestKind
    ) {
        switch kind {
        case .initial:
            activeInitialRequest = request
        case .refresh:
            activeRefreshRequest = request
        case .newer:
            activeNewerRequest = request
        case .more:
            activeMoreRequest = request
        }
    }

    private mutating func clearActiveRequests() {
        activeInitialRequest = nil
        activeRefreshRequest = nil
        activeNewerRequest = nil
        activeMoreRequest = nil
    }
}

enum ActorProfileTabRequestKind: CaseIterable, Equatable, Sendable {
    case initial
    case refresh
    case newer
    case older
}

enum ActorProfileTabRefreshPlan: Equatable, Sendable {
    case firstPage
    case newer(before: String)

    static func resolve(itemCount: Int, startCursor: String?) -> Self {
        guard itemCount > 0, let startCursor else {
            return .firstPage
        }
        return .newer(before: startCursor)
    }
}

struct ActorProfileTabRequest: Equatable, Sendable {
    let actorID: String
    let generation: UInt64
    let requestID: UInt64
    let kind: ActorProfileTabRequestKind
}

struct ActorProfileTabRequestCoordinator {
    private(set) var actorID: String
    private(set) var generation: UInt64 = 0

    private var nextRequestID: UInt64 = 0
    private var activeRequest: ActorProfileTabRequest?

    init(actorID: String) {
        self.actorID = actorID
    }

    mutating func reset(actorID: String) {
        self.actorID = actorID
        generation &+= 1
        activeRequest = nil
    }

    mutating func begin(
        _ kind: ActorProfileTabRequestKind
    ) -> ActorProfileTabRequest? {
        guard activeRequest == nil else {
            return nil
        }

        if kind == .refresh {
            generation &+= 1
        }

        nextRequestID &+= 1
        let request = ActorProfileTabRequest(
            actorID: actorID,
            generation: generation,
            requestID: nextRequestID,
            kind: kind
        )
        activeRequest = request
        return request
    }

    func isCurrent(_ request: ActorProfileTabRequest) -> Bool {
        request.actorID == actorID
            && request.generation == generation
            && activeRequest == request
    }

    @discardableResult
    mutating func finish(_ request: ActorProfileTabRequest) -> Bool {
        guard isCurrent(request) else {
            return false
        }
        activeRequest = nil
        return true
    }
}

struct ActorProfileTabPageState {
    var hasLoaded = false
    var isLoading = false
    var hasPreviousPage = false
    var hasNextPage = false
    var startCursor: String?
    var endCursor: String?
    var errorMessage: String?

    @discardableResult
    mutating func applyLoadMorePage(
        appendedCount: Int,
        nextEndCursor: String?,
        hasNextPage: Bool
    ) -> Bool {
        let madeProgress = appendedCount > 0 || nextEndCursor != endCursor
        guard madeProgress else {
            self.hasNextPage = false
            return false
        }

        hasLoaded = true
        self.hasNextPage = hasNextPage && nextEndCursor != nil
        endCursor = nextEndCursor
        errorMessage = nil
        return true
    }
}

protocol ActorProfilePageInfo {
    var hasPreviousPage: Bool { get }
    var hasNextPage: Bool { get }
    var startCursor: String? { get }
    var endCursor: String? { get }
}

extension HackersPub.ActorNotesQuery.Data.ActorByHandle.Notes.PageInfo: ActorProfilePageInfo {}
extension HackersPub.ActorArticlesQuery.Data.ActorByHandle.Articles.PageInfo: ActorProfilePageInfo {}
