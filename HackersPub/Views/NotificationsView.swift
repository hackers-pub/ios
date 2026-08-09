import SwiftUI

typealias NotificationEdge = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge

enum NotificationsPresentation {
    case primary
    case companion
}

struct NotificationsView: View {
    let controller: NotificationFeedController
    let presentation: NotificationsPresentation
    var closeCompanion: () -> Void = {}
    var openPrimaryNotifications: () -> Void = {}

    @State private var showingSettings = false
    @State private var scrollViewport = FeedViewportSnapshot<String>()
    @State private var scrollAnchorPolicy = FeedScrollAnchorPolicy<String>()
    @State private var scrollRestoreRequest: FeedScrollAnchorPolicy<String>.Restoration?
    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(NotificationReadState.self) private var notificationReadState

    private var notificationReadSession: NotificationReadSession? {
        currentNotificationReadSession(for: authManager)
    }

    private var notificationIDs: [String] {
        controller.notifications.map(\.node.id)
    }

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .primary:
            primaryView
        case .companion:
            companionView
        }
    }

    private var primaryView: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .notifications)) {
            managedFeed
                .navigationTitle(NSLocalizedString("nav.notifications", comment: "Notifications navigation title"))
                .onChange(of: navigationCoordinator.currentTab) { _, newValue in
                    guard newValue == .notifications,
                          controller.loadedSession == notificationReadSession
                    else {
                        return
                    }
                    Task {
                        await controller.refresh(
                            for: notificationReadSession,
                            readState: notificationReadState
                        )
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
                            Label(
                                NSLocalizedString("common.settings", comment: "Settings button"),
                                systemImage: "gear"
                            )
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

    private var companionView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(NSLocalizedString("nav.notifications", comment: "Notifications companion title"))
                    .font(.headline)

                Spacer()

                Button(action: openPrimaryNotifications) {
                    Label(
                        NSLocalizedString(
                            "notifications.openPrimary",
                            comment: "Open the full notifications tab"
                        ),
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
                    .labelStyle(.iconOnly)
                }
                .accessibilityLabel(
                    NSLocalizedString(
                        "notifications.openPrimary",
                        comment: "Open the full notifications tab"
                    )
                )

                Button(action: closeCompanion) {
                    Label(
                        NSLocalizedString("common.close", comment: "Close button"),
                        systemImage: "xmark"
                    )
                    .labelStyle(.iconOnly)
                }
                .accessibilityLabel(NSLocalizedString("common.close", comment: "Close button"))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .frame(minHeight: 52)

            Divider()
            managedFeed
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var managedFeed: some View {
        feed
            .refreshable {
                await controller.refresh(
                    for: notificationReadSession,
                    readState: notificationReadState
                )
            }
            .task(id: notificationReadSession) {
                resetScrollState()
                await controller.load(
                    for: notificationReadSession,
                    readState: notificationReadState
                )
            }
            .onChange(of: notificationIDs) { previousIDs, availableIDs in
                scrollAnchorPolicy.captureBeforePrepending(
                    viewport: scrollViewport,
                    existingIDs: previousIDs
                )
                scrollRestoreRequest = scrollAnchorPolicy.takeRestoration(
                    availableIDs: availableIDs
                )
            }
    }

    @ViewBuilder
    private var feed: some View {
        if controller.isLoading || controller.loadedSession == nil, controller.notifications.isEmpty {
            ProgressView()
        } else if let errorMessage = controller.errorMessage, controller.notifications.isEmpty {
            LoadFailureView(message: errorMessage) {
                Task {
                    await controller.refresh(
                        for: notificationReadSession,
                        readState: notificationReadState
                    )
                }
            }
        } else if controller.notifications.isEmpty {
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
                notifications: controller.notifications,
                isLoading: controller.isLoading,
                hasNextPage: controller.hasNextPage,
                errorMessage: controller.errorMessage,
                pendingGapInsertionIndex: controller.pendingGapInsertionIndex,
                isGapLoading: controller.isGapLoading,
                readErrorMessage: notificationReadState.presentation.readErrorMessage,
                isMarkingRead: notificationReadState.presentation.isMarking,
                loadNewer: {
                    await controller.loadGap(
                        for: notificationReadSession,
                        readState: notificationReadState
                    )
                },
                loadMore: {
                    await controller.loadOlder(
                        for: notificationReadSession,
                        readState: notificationReadState
                    )
                },
                retryLoad: {
                    await controller.retry(
                        for: notificationReadSession,
                        readState: notificationReadState
                    )
                },
                queueVisibleNotificationForRead: { notificationUUID in
                    controller.queueVisibleNotificationForRead(
                        notificationUUID,
                        for: notificationReadSession,
                        readState: notificationReadState
                    )
                },
                retryMarkingVisibleNotificationsAsRead: {
                    controller.retryMarkingVisibleNotificationsAsRead(
                        for: notificationReadSession,
                        readState: notificationReadState
                    )
                },
                navigate: navigate,
                scrollViewport: $scrollViewport,
                scrollRestoreRequest: $scrollRestoreRequest
            )
        }
    }

    private func navigate(_ action: NotificationNavigationAction) {
        switch action {
        case let .profile(handle):
            navigationCoordinator.navigateToProfile(handle: handle)
        case let .post(id):
            navigationCoordinator.navigateToPost(id: id)
        }
    }

    private func resetScrollState() {
        scrollViewport = FeedViewportSnapshot()
        scrollRestoreRequest = nil
        scrollAnchorPolicy.reset()
    }
}
