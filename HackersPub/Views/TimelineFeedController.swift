@preconcurrency import Apollo
import Foundation
import Observation

// swiftlint:disable file_length

func timelineGraphQLErrorMessages(_ errors: [GraphQLError]?) -> [String] {
    errors?.map { $0.message ?? $0.localizedDescription } ?? []
}

func isTimelineCancellation(_ error: Error) -> Bool {
    if error is CancellationError || Task.isCancelled {
        return true
    }

    guard let urlError = error as? URLError else { return false }
    return urlError.code == .cancelled
}

func applyTimelinePostContentEvent<Edge>(
    _ event: PostContentEvent,
    to state: inout TimelineState<Edge>,
    identity: (Edge) -> PostListItemIdentity
) {
    let action = PostContentListEventRouter.route(
        event,
        host: .timeline,
        rows: state.edges.map(identity),
        eventGeneration: 0,
        activeGeneration: 0
    )
    guard case let .remove(rowIDs) = action else { return }

    state.removeEdges(withIdentifiers: Set(rowIDs)) { identity($0).rowID }
}

struct TimelineFeedConnection<Edge> {
    let edges: [Edge]
    let pageInfo: TimelinePageInfo
}

struct TimelineFeedResponse<Edge> {
    let connection: TimelineFeedConnection<Edge>?
    let errorMessages: [String]
}

struct TimelineFeedSource<Edge> {
    typealias InitialResponseHandler = @MainActor (TimelineFeedResponse<Edge>) -> Void
    typealias InitialFetcher = @MainActor (@escaping InitialResponseHandler) async throws -> Void
    typealias RefreshPageFetcher = @MainActor (String?, Int) async throws -> TimelineFeedResponse<Edge>
    typealias PaginationFetcher = @MainActor (String) async throws -> TimelineFeedResponse<Edge>

    let fetchInitial: InitialFetcher
    let fetchRefreshPage: RefreshPageFetcher
    let fetchOlder: PaginationFetcher
    let fetchNewer: PaginationFetcher
    let identifier: (Edge) -> String
    let cursor: (Edge) -> String
    let identity: (Edge) -> PostListItemIdentity
    let errorFallback: String
}

@Observable
@MainActor
// The lifecycle methods share request ownership and cancellation invariants.
// swiftlint:disable:next type_body_length
final class TimelineFeedController<Edge> {
    private let source: TimelineFeedSource<Edge>
    private let pageSize: Int
    private let refreshReplayDriver = RefreshReplayDriver()
    private let taskOwner = TimelineViewTaskOwner()

    private(set) var timelineState = TimelineState<Edge>()

    var hasActiveSupervisor: Bool {
        refreshReplayDriver.hasActiveSupervisor
    }

    init(source: TimelineFeedSource<Edge>, pageSize: Int = 20) {
        self.source = source
        self.pageSize = pageSize
    }

    func supervise(initialLoadEnabled: Bool = true) async {
        await taskOwner.supervise { [weak self] in
            guard let self else { return }

            await self.refreshReplayDriver.supervise(
                initialOperation: { owner in
                    let shouldLoadInitial = self.refreshReplayDriver.withActiveOwner(owner) {
                        self.timelineState.discardStaleRequestForNewOwner()
                        return self.timelineState.shouldLoadInitial
                    } ?? false
                    if initialLoadEnabled, shouldLoadInitial {
                        await self.loadInitial(owner: owner)
                    }
                },
                isBusy: { self.timelineState.isLoading },
                operation: { owner in
                    await self.performNotificationRefresh(owner: owner)
                }
            )
        }
    }

    func cancelAll() {
        taskOwner.cancelAll()
    }

    func requestRefresh() {
        refreshReplayDriver.request()
    }

    func retry() {
        taskOwner.startRequest { [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }

    func loadMore() {
        taskOwner.startRequest { [weak self] in
            guard let self else { return }
            await self.loadMorePage()
        }
    }

    func loadNewer() {
        taskOwner.startRequest { [weak self] in
            guard let self else { return }
            await self.loadNewerPage()
        }
    }

    func refresh() async {
        guard let owner = refreshReplayDriver.currentOwner else { return }

        if timelineState.edges.isEmpty, timelineState.shouldLoadInitial {
            await loadInitial(owner: owner)
            return
        }

        let request = refreshReplayDriver.withActiveOwner(owner) {
            timelineState.beginRefresh()
        } ?? nil
        guard let request else { return }
        _ = await fetchFreshExtent(for: request, owner: owner)
    }

    func handlePostContentNotification(_ notification: Notification) {
        guard let event = PostContentEventCenter.event(from: notification) else { return }
        applyTimelinePostContentEvent(event, to: &timelineState, identity: source.identity)
    }

    private func loadInitial(owner explicitOwner: RefreshReplayOwner? = nil) async {
        guard let owner = explicitOwner ?? refreshReplayDriver.currentOwner else { return }
        let request = refreshReplayDriver.withActiveOwner(owner) {
            timelineState.beginInitial()
        } ?? nil
        guard let request else { return }
        var outcome: TimelineRequestOutcome = .cancelled
        var receivedUsableResponse = false

        defer {
            finishRequestIfOwnerIsActive(request, outcome: outcome, owner: owner)
        }

        do {
            try await source.fetchInitial { response in
                guard self.timelineState.isCurrent(request),
                      self.refreshReplayDriver.isActive(owner),
                      !Task.isCancelled
                else {
                    return
                }

                guard let responseOutcome = self.refreshReplayDriver.withActiveOwner(owner, perform: {
                    self.applyInitialResponse(
                        response,
                        request: request,
                        receivedUsableResponse: &receivedUsableResponse
                    )
                }) else {
                    return
                }
                outcome = responseOutcome
            }
        } catch {
            guard timelineState.isCurrent(request),
                  refreshReplayDriver.isActive(owner),
                  !isTimelineCancellation(error)
            else {
                return
            }
            outcome = timelineState.edges.isEmpty
                ? .failure(source.errorFallback)
                : .partialSuccess(TimelineRefreshWarning.localizedMessage)
        }
    }

    private func finishRequestIfOwnerIsActive(
        _ request: TimelineRequestToken,
        outcome: TimelineRequestOutcome,
        owner: RefreshReplayOwner,
        signalBusyRelease: Bool = true
    ) {
        _ = refreshReplayDriver.withActiveOwner(owner) {
            timelineState.finish(request, outcome: outcome)
        }
        if signalBusyRelease {
            refreshReplayDriver.notifyBusyReleased(owner: owner)
        }
    }

    private func applyInitialResponse(
        _ response: TimelineFeedResponse<Edge>,
        request: TimelineRequestToken,
        receivedUsableResponse: inout Bool
    ) -> TimelineRequestOutcome {
        let disposition = responseDisposition(for: response)

        switch disposition {
        case .usable:
            guard let connection = response.connection else { return .failure(source.errorFallback) }
            _ = timelineState.applyRefreshSnapshot(
                TimelineRefreshSnapshot(
                    edges: connection.edges,
                    pageInfo: connection.pageInfo,
                    completeness: .authoritative
                ),
                identifier: source.identifier,
                for: request
            )
            receivedUsableResponse = true
            return .success
        case let .usableWithWarning(message):
            guard let connection = response.connection else {
                return .partialSuccess(TimelineRefreshWarning.localizedMessage)
            }
            let warning = TimelineRefreshWarning.graphQLPartialResponse(debugMessage: message)
            _ = timelineState.applyRefreshSnapshot(
                TimelineRefreshSnapshot(
                    edges: connection.edges,
                    pageInfo: connection.pageInfo,
                    completeness: .partial(warning)
                ),
                identifier: source.identifier,
                for: request
            )
            receivedUsableResponse = true
            return .partialSuccess(warning.message)
        case .failure:
            return receivedUsableResponse || !timelineState.edges.isEmpty
                ? .partialSuccess(TimelineRefreshWarning.localizedMessage)
                : .failure(source.errorFallback)
        }
    }

    private func performNotificationRefresh(owner: RefreshReplayOwner) async -> RefreshReplayOperationResult {
        guard refreshReplayDriver.isActive(owner), !Task.isCancelled else { return .cancelled }
        let request = refreshReplayDriver.withActiveOwner(owner) {
            timelineState.beginRefresh()
        } ?? nil
        guard let request else { return .deferred }
        return await fetchFreshExtent(for: request, owner: owner, signalBusyReleaseAfterFinish: false)
    }

    private func fetchFreshExtent(
        for request: TimelineRequestToken,
        owner: RefreshReplayOwner,
        signalBusyReleaseAfterFinish: Bool = true
    ) async -> RefreshReplayOperationResult {
        var outcome: TimelineRequestOutcome = .cancelled
        var operationResult = RefreshReplayOperationResult.cancelled

        defer {
            finishRequestIfOwnerIsActive(
                request,
                outcome: outcome,
                owner: owner,
                signalBusyRelease: signalBusyReleaseAfterFinish
            )
        }

        do {
            let coordinator = TimelineRefreshCoordinator(
                pageSize: pageSize,
                identifier: source.identifier,
                limits: .production,
                fetchPage: fetchRefreshPage
            )
            let snapshot = try await coordinator.load(targetCount: timelineState.edges.count)
            guard timelineState.isCurrent(request),
                  !Task.isCancelled,
                  refreshReplayDriver.isActive(owner)
            else { return .cancelled }

            guard refreshReplayDriver.withActiveOwner(owner, perform: {
                _ = timelineState.applyRefreshSnapshot(
                    snapshot,
                    identifier: source.identifier,
                    for: request
                )
                return true
            }) == true else { return .cancelled }
            outcome = snapshot.warningMessage.map(TimelineRequestOutcome.partialSuccess) ?? .success
            operationResult = .completed
        } catch {
            guard timelineState.isCurrent(request),
                  !isTimelineCancellation(error),
                  refreshReplayDriver.isActive(owner)
            else {
                return .cancelled
            }
            outcome = timelineState.edges.isEmpty
                ? .failure(error.localizedDescription)
                : .partialSuccess(error.localizedDescription)
            operationResult = .completed
        }
        return operationResult
    }

    private func fetchRefreshPage(
        _ cursor: String?,
        _ pageSize: Int
    ) async throws -> TimelineRefreshPage<Edge> {
        let response = try await timelineRefreshResponse(userMessage: source.errorFallback) {
            try await source.fetchRefreshPage(cursor, pageSize)
        }
        guard let connection = response.connection else {
            throw TimelineRefreshError(
                userMessage: source.errorFallback,
                debugMessage: response.errorMessages.first
            )
        }

        return TimelineRefreshPage(
            edges: connection.edges,
            pageInfo: connection.pageInfo,
            warning: TimelineRefreshWarning.graphQLPartialResponse(debugMessages: response.errorMessages)
        )
    }

    private func loadMorePage() async {
        guard let owner = refreshReplayDriver.currentOwner else { return }
        let request = refreshReplayDriver.withActiveOwner(owner) {
            timelineState.beginMore()
        } ?? nil
        guard let request, let cursor = timelineState.endCursor else { return }
        var outcome: TimelineRequestOutcome = .cancelled

        defer {
            finishRequestIfOwnerIsActive(request, outcome: outcome, owner: owner)
        }

        do {
            let response = try await source.fetchOlder(cursor)
            guard timelineState.isCurrent(request),
                  refreshReplayDriver.isActive(owner),
                  !Task.isCancelled
            else {
                return
            }

            guard let responseOutcome = refreshReplayDriver.withActiveOwner(owner, perform: {
                applyMoreResponse(response, request: request)
            }) else {
                return
            }
            outcome = responseOutcome
        } catch {
            guard timelineState.isCurrent(request),
                  refreshReplayDriver.isActive(owner),
                  !isTimelineCancellation(error)
            else {
                return
            }
            outcome = .partialSuccess(error.localizedDescription)
        }
    }
}

private extension TimelineFeedController {
    func applyMoreResponse(
        _ response: TimelineFeedResponse<Edge>,
        request: TimelineRequestToken
    ) -> TimelineRequestOutcome {
        switch responseDisposition(for: response) {
        case .usable:
            guard let connection = response.connection else { return .failure(source.errorFallback) }
            _ = timelineState.appendPage(
                connection.edges,
                pageInfo: connection.pageInfo,
                identifier: source.identifier,
                for: request
            )
            return .success
        case let .usableWithWarning(message):
            if let connection = response.connection, !connection.edges.isEmpty {
                _ = timelineState.appendPage(
                    connection.edges,
                    pageInfo: connection.pageInfo,
                    identifier: source.identifier,
                    for: request
                )
            }
            return .partialSuccess(message)
        case let .failure(message):
            return .partialSuccess(message)
        }
    }

    func loadNewerPage() async {
        guard let owner = refreshReplayDriver.currentOwner else { return }
        let request = refreshReplayDriver.withActiveOwner(owner) {
            timelineState.beginNewer()
        } ?? nil
        guard let request,
              let cursor = timelineState.pendingNewerCursor ?? timelineState.startCursor
        else {
            return
        }
        var outcome: TimelineRequestOutcome = .cancelled

        defer {
            finishRequestIfOwnerIsActive(request, outcome: outcome, owner: owner)
        }

        do {
            let response = try await source.fetchNewer(cursor)
            guard timelineState.isCurrent(request),
                  refreshReplayDriver.isActive(owner),
                  !Task.isCancelled
            else {
                return
            }

            guard let responseOutcome = refreshReplayDriver.withActiveOwner(owner, perform: {
                applyNewerResponse(response, request: request)
            }) else {
                return
            }
            outcome = responseOutcome
        } catch {
            guard timelineState.isCurrent(request),
                  refreshReplayDriver.isActive(owner),
                  !isTimelineCancellation(error)
            else {
                return
            }
            outcome = .partialSuccess(error.localizedDescription)
        }
    }

    func applyNewerResponse(
        _ response: TimelineFeedResponse<Edge>,
        request: TimelineRequestToken
    ) -> TimelineRequestOutcome {
        switch responseDisposition(for: response) {
        case .usable:
            guard let connection = response.connection else { return .failure(source.errorFallback) }
            mergeNewerConnection(connection, for: request)
            return .success
        case let .usableWithWarning(message):
            if let connection = response.connection, !connection.edges.isEmpty {
                mergeNewerConnection(connection, for: request)
            }
            return .partialSuccess(message)
        case let .failure(message):
            return .partialSuccess(message)
        }
    }

    func mergeNewerConnection(
        _ connection: TimelineFeedConnection<Edge>,
        for request: TimelineRequestToken
    ) {
        _ = timelineState.mergeNewerPage(
            connection.edges,
            page: TimelineNewerPage(
                nextCursor: connection.pageInfo.startCursor,
                hasMoreNewer: connection.pageInfo.hasPreviousPage,
                fallbackEndCursor: connection.pageInfo.endCursor
            ),
            cursor: source.cursor,
            identifier: source.identifier,
            for: request
        )
    }

    func responseDisposition(
        for response: TimelineFeedResponse<Edge>
    ) -> TimelineResponseDisposition {
        TimelineResponsePolicy.disposition(
            hasConnection: response.connection != nil,
            incomingCount: response.connection?.edges.count ?? 0,
            hasExistingContent: !timelineState.edges.isEmpty,
            graphQLErrorMessages: response.errorMessages,
            fallbackMessage: source.errorFallback
        )
    }
}

extension TimelineFeedSource where Edge == HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge {
    static var publicTimeline: Self {
        Self(
            fetchInitial: { receive in
                let request = TimelineInitialRequestFactory.publicTimeline()
                let responses = try apolloClient.fetch(query: request.query, cachePolicy: request.cachePolicy)
                for try await response in responses {
                    receive(
                        TimelineFeedResponse(
                            connection: response.data.map { data in
                                TimelineFeedConnection(
                                    edges: data.publicTimeline.edges,
                                    pageInfo: timelinePageInfo(data.publicTimeline.pageInfo)
                                )
                            },
                            errorMessages: timelineGraphQLErrorMessages(response.errors)
                        )
                    )
                }
            },
            fetchRefreshPage: { cursor, pageSize in
                let query: HackersPub.PublicTimelineQuery
                if let cursor {
                    query = HackersPub.PublicTimelineQuery(
                        after: .some(cursor), before: nil, first: .some(Int32(pageSize)), last: nil
                    )
                } else {
                    query = HackersPub.PublicTimelineQuery(
                        after: nil, before: nil, first: .some(Int32(pageSize)), last: nil
                    )
                }
                let response = try await apolloClient.fetch(query: query, cachePolicy: .networkOnly)
                return TimelineFeedResponse(
                    connection: response.data.map { data in
                        TimelineFeedConnection(
                            edges: data.publicTimeline.edges,
                            pageInfo: timelinePageInfo(data.publicTimeline.pageInfo)
                        )
                    },
                    errorMessages: timelineGraphQLErrorMessages(response.errors)
                )
            },
            fetchOlder: { cursor in
                let response = try await apolloClient.fetch(
                    query: HackersPub.PublicTimelineQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                    cachePolicy: .networkOnly
                )
                return TimelineFeedResponse(
                    connection: response.data.map { data in
                        TimelineFeedConnection(
                            edges: data.publicTimeline.edges,
                            pageInfo: timelinePageInfo(data.publicTimeline.pageInfo)
                        )
                    },
                    errorMessages: timelineGraphQLErrorMessages(response.errors)
                )
            },
            fetchNewer: { cursor in
                let response = try await apolloClient.fetch(
                    query: HackersPub.PublicTimelineQuery(after: nil, before: .some(cursor), first: nil, last: 20),
                    cachePolicy: .networkOnly
                )
                return TimelineFeedResponse(
                    connection: response.data.map { data in
                        TimelineFeedConnection(
                            edges: data.publicTimeline.edges,
                            pageInfo: timelinePageInfo(data.publicTimeline.pageInfo)
                        )
                    },
                    errorMessages: timelineGraphQLErrorMessages(response.errors)
                )
            },
            identifier: \.timelineListID,
            cursor: \.cursor,
            identity: { postListItemIdentity(rowID: $0.timelineListID, post: $0.node) },
            errorFallback: timelineErrorFallback
        )
    }
}

extension TimelineFeedSource where Edge == HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge {
    static var personalTimeline: Self {
        Self(
            fetchInitial: { receive in
                let request = TimelineInitialRequestFactory.personalTimeline()
                let responses = try apolloClient.fetch(query: request.query, cachePolicy: request.cachePolicy)
                for try await response in responses {
                    receive(
                        TimelineFeedResponse(
                            connection: response.data.map { data in
                                TimelineFeedConnection(
                                    edges: data.personalTimeline.edges,
                                    pageInfo: timelinePageInfo(data.personalTimeline.pageInfo)
                                )
                            },
                            errorMessages: timelineGraphQLErrorMessages(response.errors)
                        )
                    )
                }
            },
            fetchRefreshPage: { cursor, pageSize in
                let query: HackersPub.PersonalTimelineQuery
                if let cursor {
                    query = HackersPub.PersonalTimelineQuery(
                        after: .some(cursor), before: nil, first: .some(Int32(pageSize)), last: nil
                    )
                } else {
                    query = HackersPub.PersonalTimelineQuery(
                        after: nil, before: nil, first: .some(Int32(pageSize)), last: nil
                    )
                }
                let response = try await apolloClient.fetch(query: query, cachePolicy: .networkOnly)
                return TimelineFeedResponse(
                    connection: response.data.map { data in
                        TimelineFeedConnection(
                            edges: data.personalTimeline.edges,
                            pageInfo: timelinePageInfo(data.personalTimeline.pageInfo)
                        )
                    },
                    errorMessages: timelineGraphQLErrorMessages(response.errors)
                )
            },
            fetchOlder: { cursor in
                let response = try await apolloClient.fetch(
                    query: HackersPub.PersonalTimelineQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                    cachePolicy: .networkOnly
                )
                return TimelineFeedResponse(
                    connection: response.data.map { data in
                        TimelineFeedConnection(
                            edges: data.personalTimeline.edges,
                            pageInfo: timelinePageInfo(data.personalTimeline.pageInfo)
                        )
                    },
                    errorMessages: timelineGraphQLErrorMessages(response.errors)
                )
            },
            fetchNewer: { cursor in
                let response = try await apolloClient.fetch(
                    query: HackersPub.PersonalTimelineQuery(after: nil, before: .some(cursor), first: nil, last: 20),
                    cachePolicy: .networkOnly
                )
                return TimelineFeedResponse(
                    connection: response.data.map { data in
                        TimelineFeedConnection(
                            edges: data.personalTimeline.edges,
                            pageInfo: timelinePageInfo(data.personalTimeline.pageInfo)
                        )
                    },
                    errorMessages: timelineGraphQLErrorMessages(response.errors)
                )
            },
            identifier: \.timelineListID,
            cursor: \.cursor,
            identity: { postListItemIdentity(rowID: $0.timelineListID, post: $0.node) },
            errorFallback: timelineErrorFallback
        )
    }
}

extension TimelineFeedSource where Edge == HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge {
    static var localTimeline: Self {
        Self(
            fetchInitial: { receive in
                let request = TimelineInitialRequestFactory.localTimeline()
                let responses = try apolloClient.fetch(query: request.query, cachePolicy: request.cachePolicy)
                for try await response in responses {
                    receive(
                        TimelineFeedResponse(
                            connection: response.data.map { data in
                                TimelineFeedConnection(
                                    edges: data.publicTimeline.edges,
                                    pageInfo: timelinePageInfo(data.publicTimeline.pageInfo)
                                )
                            },
                            errorMessages: timelineGraphQLErrorMessages(response.errors)
                        )
                    )
                }
            },
            fetchRefreshPage: { cursor, pageSize in
                let query: HackersPub.LocalTimelineQuery
                if let cursor {
                    query = HackersPub.LocalTimelineQuery(
                        after: .some(cursor), before: nil, first: .some(Int32(pageSize)), last: nil
                    )
                } else {
                    query = HackersPub.LocalTimelineQuery(
                        after: nil, before: nil, first: .some(Int32(pageSize)), last: nil
                    )
                }
                let response = try await apolloClient.fetch(query: query, cachePolicy: .networkOnly)
                return TimelineFeedResponse(
                    connection: response.data.map { data in
                        TimelineFeedConnection(
                            edges: data.publicTimeline.edges,
                            pageInfo: timelinePageInfo(data.publicTimeline.pageInfo)
                        )
                    },
                    errorMessages: timelineGraphQLErrorMessages(response.errors)
                )
            },
            fetchOlder: { cursor in
                let response = try await apolloClient.fetch(
                    query: HackersPub.LocalTimelineQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                    cachePolicy: .networkOnly
                )
                return TimelineFeedResponse(
                    connection: response.data.map { data in
                        TimelineFeedConnection(
                            edges: data.publicTimeline.edges,
                            pageInfo: timelinePageInfo(data.publicTimeline.pageInfo)
                        )
                    },
                    errorMessages: timelineGraphQLErrorMessages(response.errors)
                )
            },
            fetchNewer: { cursor in
                let response = try await apolloClient.fetch(
                    query: HackersPub.LocalTimelineQuery(after: nil, before: .some(cursor), first: nil, last: 20),
                    cachePolicy: .networkOnly
                )
                return TimelineFeedResponse(
                    connection: response.data.map { data in
                        TimelineFeedConnection(
                            edges: data.publicTimeline.edges,
                            pageInfo: timelinePageInfo(data.publicTimeline.pageInfo)
                        )
                    },
                    errorMessages: timelineGraphQLErrorMessages(response.errors)
                )
            },
            identifier: \.timelineListID,
            cursor: \.cursor,
            identity: { postListItemIdentity(rowID: $0.timelineListID, post: $0.node) },
            errorFallback: timelineErrorFallback
        )
    }
}

private let timelineErrorFallback = NSLocalizedString(
    "timeline.error.unavailable",
    comment: "Timeline unavailable error"
)

private func timelinePageInfo(
    _ pageInfo: HackersPub.PublicTimelineQuery.Data.PublicTimeline.PageInfo
) -> TimelinePageInfo {
    TimelinePageInfo(
        hasPreviousPage: pageInfo.hasPreviousPage,
        hasNextPage: pageInfo.hasNextPage,
        startCursor: pageInfo.startCursor,
        endCursor: pageInfo.endCursor
    )
}

private func timelinePageInfo(
    _ pageInfo: HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.PageInfo
) -> TimelinePageInfo {
    TimelinePageInfo(
        hasPreviousPage: pageInfo.hasPreviousPage,
        hasNextPage: pageInfo.hasNextPage,
        startCursor: pageInfo.startCursor,
        endCursor: pageInfo.endCursor
    )
}

private func timelinePageInfo(
    _ pageInfo: HackersPub.LocalTimelineQuery.Data.PublicTimeline.PageInfo
) -> TimelinePageInfo {
    TimelinePageInfo(
        hasPreviousPage: pageInfo.hasPreviousPage,
        hasNextPage: pageInfo.hasNextPage,
        startCursor: pageInfo.startCursor,
        endCursor: pageInfo.endCursor
    )
}
