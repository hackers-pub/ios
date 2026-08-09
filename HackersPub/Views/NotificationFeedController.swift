@preconcurrency import Apollo
import Foundation
import Observation

@MainActor
@Observable
final class NotificationFeedController {
    private var feedState = NotificationFeedState<NotificationEdge>(id: { $0.node.id })
    private(set) var loadedSession: NotificationReadSession?
    @ObservationIgnored private var initialLoadTask: Task<Void, Never>?

    var notifications: [NotificationEdge] {
        feedState.items
    }

    var isLoading: Bool {
        feedState.isLoading
    }

    var errorMessage: String? {
        feedState.errorMessage
    }

    var hasNextPage: Bool {
        feedState.hasNextPage
    }

    var pendingGapInsertionIndex: Int? {
        feedState.pendingGapInsertionIndex
    }

    var isGapLoading: Bool {
        feedState.isGapLoading
    }

    func load(
        for session: NotificationReadSession?,
        readState: NotificationReadState
    ) async {
        guard let session else {
            reset(for: nil)
            return
        }
        if loadedSession == session {
            await initialLoadTask?.value
            return
        }

        // Claim the session before suspension so primary and companion tasks
        // cannot both start the initial request.
        reset(for: session)
        let task = Task { [weak self] in
            guard let self else { return }
            await fetchNotifications(for: session, readState: readState)
            if loadedSession == session {
                initialLoadTask = nil
            }
        }
        initialLoadTask = task
        await task.value
    }

    func refresh(
        for session: NotificationReadSession?,
        readState: NotificationReadState
    ) async {
        guard loadedSession == session, let session else { return }

        // A refresh is always a new first-page request. It does not consume a
        // pending gap cursor, so new notifications remain reachable while the
        // middle gap is being filled.
        await fetchNotifications(for: session, readState: readState, cachePolicy: .networkOnly)
    }

    func loadOlder(
        for session: NotificationReadSession?,
        readState: NotificationReadState
    ) async {
        guard let session,
              loadedSession == session,
              let feedRequest = feedState.beginOlderRequest(),
              let cursor = feedRequest.cursor,
              let request = beginListRequest(for: session, readState: readState)
        else {
            return
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.NotificationsQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                cachePolicy: .networkOnly
            )
            guard isCurrent(request) else {
                _ = feedState.finishOlder(feedRequest, with: .cancelled)
                return
            }

            let viewer = try notificationsViewer(from: response, for: request)
            guard isCurrent(request) else {
                _ = feedState.finishOlder(feedRequest, with: .cancelled)
                return
            }

            if feedState.finishOlder(
                feedRequest,
                with: .success(notificationPage(from: viewer.notifications))
            ) {
                _ = readState.applyUnreadCount(viewer.unreadNotificationsCount, for: request.unreadRequest)
            }
        } catch is CancellationError {
            _ = feedState.finishOlder(feedRequest, with: .cancelled)
        } catch {
            _ = feedState.finishOlder(feedRequest, with: .failure(error.localizedDescription))
        }
    }

    func loadGap(
        for session: NotificationReadSession?,
        readState: NotificationReadState
    ) async {
        guard let session,
              loadedSession == session,
              let feedRequest = feedState.beginGapRequest(),
              let cursor = feedRequest.cursor,
              let request = beginListRequest(for: session, readState: readState)
        else {
            return
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.NotificationsQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                cachePolicy: .networkOnly
            )
            guard isCurrent(request) else {
                _ = feedState.finishGap(feedRequest, with: .cancelled)
                return
            }

            let viewer = try notificationsViewer(from: response, for: request)
            guard isCurrent(request) else {
                _ = feedState.finishGap(feedRequest, with: .cancelled)
                return
            }

            if feedState.finishGap(
                feedRequest,
                with: .success(notificationPage(from: viewer.notifications))
            ) {
                _ = readState.applyUnreadCount(viewer.unreadNotificationsCount, for: request.unreadRequest)
            }
        } catch is CancellationError {
            _ = feedState.finishGap(feedRequest, with: .cancelled)
        } catch {
            _ = feedState.finishGap(feedRequest, with: .failure(error.localizedDescription))
        }
    }

    func retry(
        for session: NotificationReadSession?,
        readState: NotificationReadState
    ) async {
        if feedState.hasPendingGap {
            await loadGap(for: session, readState: readState)
        } else {
            await refresh(for: session, readState: readState)
        }
    }

    func queueVisibleNotificationForRead(
        _ notificationUUID: String,
        for session: NotificationReadSession?,
        readState: NotificationReadState
    ) {
        // `Account.notifications` is server-ordered newest first, so the first
        // rendered UUID is the safe read-through boundary for `upTo`.
        guard notificationUUID == notifications.first?.node.uuid,
              let session,
              session == loadedSession
        else {
            return
        }

        Task {
            _ = await readState.markDisplayedNotificationsAsRead(
                upTo: notificationUUID,
                for: session
            )
        }
    }

    func retryMarkingVisibleNotificationsAsRead(
        for session: NotificationReadSession?,
        readState: NotificationReadState
    ) {
        guard let notificationUUID = notifications.first?.node.uuid else { return }
        queueVisibleNotificationForRead(notificationUUID, for: session, readState: readState)
    }
}

private extension NotificationFeedController {
    func reset(for session: NotificationReadSession?) {
        initialLoadTask?.cancel()
        initialLoadTask = nil
        feedState.reset()
        loadedSession = session
    }

    func beginListRequest(
        for session: NotificationReadSession,
        readState: NotificationReadState
    ) -> NotificationListRequest? {
        guard loadedSession == session,
              let unreadRequest = readState.beginUnreadRequest(for: session)
        else {
            return nil
        }

        return NotificationListRequest(session: session, unreadRequest: unreadRequest)
    }

    func isCurrent(_ request: NotificationListRequest) -> Bool {
        !Task.isCancelled && request.session == loadedSession
    }

    func notificationsViewer(
        from response: GraphQLResponse<HackersPub.NotificationsQuery>,
        for request: NotificationListRequest
    ) throws -> HackersPub.NotificationsQuery.Data.Viewer {
        if let error = response.errors?.first {
            throw NotificationsLoadError.graphQLError(error.message ?? "")
        }
        guard let viewer = response.data?.viewer,
              viewer.id == request.session.accountID
        else {
            throw NotificationsLoadError.missingViewer
        }
        return viewer
    }

    func fetchNotifications(
        for session: NotificationReadSession,
        readState: NotificationReadState,
        cachePolicy: CachePolicy.Query.SingleResponse = .networkFirst
    ) async {
        guard loadedSession == session,
              var feedRequest = feedState.beginLatestRequest()
        else {
            return
        }

        while true {
            guard let request = beginListRequest(for: session, readState: readState) else {
                _ = feedState.finishLatest(feedRequest, with: .cancelled)
                return
            }

            do {
                let response = try await apolloClient.fetch(
                    query: HackersPub.NotificationsQuery(after: nil, before: nil, first: 20, last: nil),
                    cachePolicy: cachePolicy
                )
                guard isCurrent(request) else {
                    _ = feedState.finishLatest(feedRequest, with: .cancelled)
                    return
                }

                let viewer = try notificationsViewer(from: response, for: request)
                guard isCurrent(request) else {
                    _ = feedState.finishLatest(feedRequest, with: .cancelled)
                    return
                }

                let nextRequest = feedState.finishLatest(
                    feedRequest,
                    with: .success(notificationPage(from: viewer.notifications))
                )
                _ = readState.applyUnreadCount(viewer.unreadNotificationsCount, for: request.unreadRequest)
                guard let nextRequest else { return }
                feedRequest = nextRequest
            } catch is CancellationError {
                guard let nextRequest = feedState.finishLatest(feedRequest, with: .cancelled) else {
                    return
                }
                feedRequest = nextRequest
            } catch {
                guard let nextRequest = feedState.finishLatest(
                    feedRequest,
                    with: .failure(error.localizedDescription)
                ) else {
                    return
                }
                feedRequest = nextRequest
            }
        }
    }

    func notificationPage(
        from connection: HackersPub.NotificationsQuery.Data.Viewer.Notifications
    ) -> NotificationFeedPage<NotificationEdge> {
        NotificationFeedPage(
            items: connection.edges,
            startCursor: connection.pageInfo.startCursor,
            endCursor: connection.pageInfo.endCursor,
            hasNextPage: connection.pageInfo.hasNextPage
        )
    }
}
