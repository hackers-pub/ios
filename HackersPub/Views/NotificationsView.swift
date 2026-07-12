@preconcurrency import Apollo
import SwiftUI

typealias NotificationEdge = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge

struct NotificationsView: View {
    @State private var feedState = NotificationFeedState<NotificationEdge>(id: { $0.node.id })
    @State private var loadedSession: NotificationReadSession?
    @State private var showingSettings = false
    @State private var scrollViewport = FeedViewportSnapshot<String>()
    @State private var scrollAnchorPolicy = FeedScrollAnchorPolicy<String>()
    @State private var scrollRestoreRequest: FeedScrollAnchorPolicy<String>.Restoration?
    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(NotificationReadState.self) private var notificationReadState

    private var isLoading: Bool {
        feedState.isLoading
    }

    private var notificationReadSession: NotificationReadSession? {
        currentNotificationReadSession(for: authManager)
    }

    private var notifications: [NotificationEdge] {
        feedState.items
    }

    private var errorMessage: String? {
        feedState.errorMessage
    }

    private var hasNextPage: Bool {
        feedState.hasNextPage
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .notifications)) {
            Group {
                if (isLoading || loadedSession == nil) && notifications.isEmpty {
                    ProgressView()
                } else if let errorMessage, notifications.isEmpty {
                    LoadFailureView(message: errorMessage) {
                        Task {
                            await fetchNotifications()
                        }
                    }
                } else if notifications.isEmpty {
                    let emptyDescription = NSLocalizedString(
                        "notifications.empty.description",
                        comment: "No notifications description"
                    )
                    ContentUnavailableView(
                        NSLocalizedString("notifications.empty.title", comment: "No notifications title"),
                        systemImage: "bell.slash",
                        description: Text(emptyDescription)
                    )
                } else {
                    NotificationFeedContent(
                        notifications: notifications,
                        isLoading: isLoading,
                        hasNextPage: hasNextPage,
                        errorMessage: errorMessage,
                        pendingGapInsertionIndex: feedState.pendingGapInsertionIndex,
                        isGapLoading: feedState.isGapLoading,
                        readErrorMessage: notificationReadState.presentation.readErrorMessage,
                        isMarkingRead: notificationReadState.presentation.isMarking,
                        loadNewer: loadNewerNotifications,
                        loadMore: loadMore,
                        retryLoad: retryFailedNotificationsRequest,
                        queueVisibleNotificationForRead: queueVisibleNotificationForRead,
                        retryMarkingVisibleNotificationsAsRead: retryMarkingVisibleNotificationsAsRead,
                        scrollViewport: $scrollViewport,
                        scrollRestoreRequest: $scrollRestoreRequest
                    )
                }
            }
            .navigationTitle(NSLocalizedString("nav.notifications", comment: "Notifications navigation title"))
            .refreshable {
                await refreshNotifications()
            }
            .task(id: notificationReadSession) {
                await loadNotificationsForCurrentSession()
            }
            .onChange(of: navigationCoordinator.currentTab) { _, newValue in
                guard newValue == .notifications,
                      loadedSession == notificationReadSession
                else {
                    return
                }
                Task {
                    await refreshNotifications()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ViewerProfileButton()
                }

                ToolbarItem(placement: .navigation) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label(NSLocalizedString("common.settings", comment: "Settings button"), systemImage: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case let .profile(handle):
                    ActorProfileViewWrapper(handle: handle)
                case let .post(id):
                    PostDetailView(postId: id)
                case let .newsStory(id):
                    NewsStoryDetailView(storyId: id)
                }
            }
        }
    }
}

private extension NotificationsView {
    private func loadNotificationsForCurrentSession() async {
        guard let session = notificationReadSession else {
            resetNotifications(for: nil)
            return
        }
        guard loadedSession != session else { return }

        resetNotifications(for: session)
        await fetchNotifications()
    }

    private func resetNotifications(for session: NotificationReadSession?) {
        feedState.reset()
        loadedSession = session
        scrollViewport = FeedViewportSnapshot()
        scrollRestoreRequest = nil
        scrollAnchorPolicy.reset()
    }

    private func captureScrollAnchorBeforeFeedMutation() {
        scrollAnchorPolicy.captureBeforePrepending(
            viewport: scrollViewport,
            existingIDs: notifications.map { $0.node.id }
        )
    }

    private func scheduleScrollAnchorRestoration() {
        scrollRestoreRequest = scrollAnchorPolicy.takeRestoration(
            availableIDs: notifications.map { $0.node.id }
        )
    }

    private func beginListRequest() -> NotificationListRequest? {
        guard let session = notificationReadSession,
              loadedSession == session,
              let unreadRequest = notificationReadState.beginUnreadRequest(for: session)
        else {
            return nil
        }

        return NotificationListRequest(
            session: session,
            unreadRequest: unreadRequest
        )
    }

    private func isCurrent(_ request: NotificationListRequest) -> Bool {
        !Task.isCancelled
            && request.session == loadedSession
            && request.session == notificationReadSession
    }

    private func notificationsViewer(
        from response: GraphQLResponse<HackersPub.NotificationsQuery>,
        for request: NotificationListRequest
    ) throws -> HackersPub.NotificationsQuery.Data.Viewer {
        if let error = response.errors?.first {
            throw NotificationsLoadError.graphQLError(error.message ?? "")
        }
        guard let viewer = response.data?.viewer else {
            throw NotificationsLoadError.missingViewer
        }
        guard viewer.id == request.session.accountID else {
            throw NotificationsLoadError.missingViewer
        }
        return viewer
    }

    private func fetchNotifications(
        cachePolicy: CachePolicy.Query.SingleResponse = .networkFirst
    ) async {
        guard loadedSession == notificationReadSession,
              var feedRequest = feedState.beginLatestRequest()
        else {
            return
        }

        while true {
            guard let request = beginListRequest() else {
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

                let nextRequest = finishLatestSuccess(
                    feedRequest: feedRequest,
                    viewer: viewer,
                    request: request
                )
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

    private func finishLatestSuccess(
        feedRequest: NotificationFeedRequest,
        viewer: HackersPub.NotificationsQuery.Data.Viewer,
        request: NotificationListRequest
    ) -> NotificationFeedRequest? {
        captureScrollAnchorBeforeFeedMutation()
        let nextRequest = feedState.finishLatest(
            feedRequest,
            with: .success(notificationPage(from: viewer.notifications))
        )
        scheduleScrollAnchorRestoration()
        _ = notificationReadState.applyUnreadCount(
            viewer.unreadNotificationsCount,
            for: request.unreadRequest
        )
        return nextRequest
    }

    private func loadMore() async {
        guard let feedRequest = feedState.beginOlderRequest(),
              let cursor = feedRequest.cursor,
              let request = beginListRequest()
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
                _ = notificationReadState.applyUnreadCount(
                    viewer.unreadNotificationsCount,
                    for: request.unreadRequest
                )
            }
        } catch is CancellationError {
            _ = feedState.finishOlder(feedRequest, with: .cancelled)
        } catch {
            _ = feedState.finishOlder(feedRequest, with: .failure(error.localizedDescription))
        }
    }

    private func refreshNotifications() async {
        guard loadedSession == notificationReadSession else { return }

        // A refresh is always a new first-page request. It does not consume a
        // pending gap cursor, so new notifications remain reachable while the
        // middle gap is being filled.
        await fetchNotifications(cachePolicy: .networkOnly)
    }

    private func loadNewerNotifications() async {
        guard let feedRequest = feedState.beginGapRequest(),
              let cursor = feedRequest.cursor,
              let request = beginListRequest()
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

            captureScrollAnchorBeforeFeedMutation()
            if feedState.finishGap(
                feedRequest,
                with: .success(notificationPage(from: viewer.notifications))
            ) {
                scheduleScrollAnchorRestoration()
                _ = notificationReadState.applyUnreadCount(
                    viewer.unreadNotificationsCount,
                    for: request.unreadRequest
                )
            }
        } catch is CancellationError {
            _ = feedState.finishGap(feedRequest, with: .cancelled)
        } catch {
            _ = feedState.finishGap(feedRequest, with: .failure(error.localizedDescription))
        }
    }

    private func retryFailedNotificationsRequest() async {
        if feedState.hasPendingGap {
            await loadNewerNotifications()
        } else {
            await refreshNotifications()
        }
    }

    private func queueVisibleNotificationForRead(_ notificationUUID: String) {
        // `Account.notifications` is server-ordered newest first, so the first
        // rendered UUID is the safe read-through boundary for `upTo`.
        guard notificationUUID == notifications.first?.node.uuid,
              let session = notificationReadSession
        else {
            return
        }

        Task {
            _ = await notificationReadState.markDisplayedNotificationsAsRead(
                upTo: notificationUUID,
                for: session
            )
        }
    }

    private func retryMarkingVisibleNotificationsAsRead() {
        guard let notificationUUID = notifications.first?.node.uuid else { return }
        queueVisibleNotificationForRead(notificationUUID)
    }

    private func notificationPage(
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
