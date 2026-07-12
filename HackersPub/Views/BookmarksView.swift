@preconcurrency import Apollo
import SwiftUI

struct BookmarksView: View {
    @Binding var showingComposeView: Bool
    @State private var selectedFilter: BookmarkFilter = .all
    @State private var edges: [HackersPub.BookmarksQuery.Data.Bookmarks.Edge] = []
    @State private var isLoading = false
    @State private var hasLoadedInitial = false
    @State private var errorMessage: String?
    @State private var hasPreviousPage = false
    @State private var hasNextPage = false
    @State private var startCursor: String?
    @State private var endCursor: String?
    @State private var pendingNewerCursor: String?
    @State private var requestCoordinator = BookmarkFilterRequestCoordinator(filterID: BookmarkFilter.all.id)
    @State private var listRequestTask: Task<Void, Never>?
    @State private var listRequestToken: BookmarkFilterRequestToken?
    @State private var newerRequestTask: Task<Void, Never>?
    @State private var newerRequestToken: BookmarkFilterRequestToken?
    @State private var scrollViewport = FeedViewportSnapshot<String>()
    @State private var scrollAnchorPolicy = FeedScrollAnchorPolicy<String>()
    @State private var scrollRestoreRequest: FeedScrollAnchorPolicy<String>.Restoration?
    @State private var showingSettings = false
    @State private var showingArticleEditor = false
    @State private var showingArticleDrafts = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        _showingComposeView = showingComposeView
    }

    var body: some View {
        Group {
            if isLoading && edges.isEmpty {
                ProgressView()
            } else if let errorMessage, edges.isEmpty {
                VStack(spacing: 12) {
                    ContentUnavailableView(
                        NSLocalizedString("error.loadFailed.title", comment: "Load failure title"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )

                    Button(NSLocalizedString("common.retry", comment: "Retry button")) {
                        startListRequest(reset: true, cachePolicy: .networkOnly)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if hasLoadedInitial && edges.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString("bookmarks.empty.title", comment: "No bookmarks title"),
                    systemImage: "bookmark",
                    description: Text(NSLocalizedString("bookmarks.empty.description", comment: "Bookmarks empty"))
                )
            } else {
                BookmarkFeedContent(
                    edges: edges,
                    isLoading: isLoading,
                    hasPreviousPage: hasPreviousPage,
                    errorMessage: errorMessage,
                    loadNewer: loadNewerBookmarks,
                    loadMore: loadMore,
                    refresh: refreshBookmarks,
                    retry: loadMore,
                    onBookmarkChanged: handleBookmarkChange,
                    shouldLoadMore: { shouldLoadMore(afterAppearing: $0) },
                    scrollViewport: $scrollViewport,
                    scrollRestoreRequest: $scrollRestoreRequest
                )
            }
        }
        .navigationTitle(NSLocalizedString("bookmarks.title", comment: "Bookmarks navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            BookmarkNavigationToolbar(
                showingComposeView: $showingComposeView,
                selectedFilter: $selectedFilter,
                showingSettings: $showingSettings,
                showingArticleEditor: $showingArticleEditor,
                showingArticleDrafts: $showingArticleDrafts
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingArticleEditor) {
            ArticleEditorView {
                showingArticleEditor = false
                startListRequest(reset: true, cachePolicy: .networkOnly)
            }
        }
        .sheet(isPresented: $showingArticleDrafts) {
            ArticleDraftListView()
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
        .task {
            guard !hasLoadedInitial else { return }
            startListRequest(reset: true, cachePolicy: .networkFirst)
        }
        .onChange(of: selectedFilter) {
            handleFilterChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: .postContentDidChange)) { notification in
            handlePostContentNotification(notification)
        }
    }
}

private extension BookmarksView {
    func reset() {
        listRequestTask?.cancel()
        newerRequestTask?.cancel()
        listRequestTask = nil
        listRequestToken = nil
        newerRequestTask = nil
        newerRequestToken = nil
        requestCoordinator.select(filterID: selectedFilter.id)
        edges = []
        isLoading = false
        hasLoadedInitial = false
        hasPreviousPage = false
        hasNextPage = false
        startCursor = nil
        endCursor = nil
        pendingNewerCursor = nil
        errorMessage = nil
        scrollViewport = FeedViewportSnapshot()
        scrollRestoreRequest = nil
        scrollAnchorPolicy.reset()
    }

    private func handleFilterChange() {
        reset()
        startListRequest(reset: true, cachePolicy: .networkOnly)
    }

    private func loadMore() async {
        guard hasNextPage, endCursor != nil else { return }
        await startListRequest(reset: false, cachePolicy: .networkFirst).value
    }

    private func refreshBookmarks() async {
        guard !isLoading else { return }
        if edges.isEmpty || startCursor == nil {
            await startListRequest(reset: true, cachePolicy: .networkOnly).value
            return
        }
        if let task = startNewerRequest() {
            await task.value
        }
    }

    private func handleBookmarkChange(postID: String, isBookmarked: Bool) {
        applyPostContentAction(
            BookmarkFeedIntegration.action(postID: postID, isBookmarked: isBookmarked, edges: edges)
        )
    }

    private func applyPostContentAction(_ action: BookmarkFeedPostContentAction) {
        switch action {
        case .none:
            return
        case .authoritativeRefresh:
            invalidateActiveRequests()
            startListRequest(reset: true, cachePolicy: .networkOnly)
        case let .remove(nodeIDs):
            guard !nodeIDs.isEmpty else { return }
            invalidateActiveRequests()
            edges.removeAll { nodeIDs.contains($0.node.id) }
        }
    }

    private func invalidateActiveRequests() {
        requestCoordinator.invalidateActiveRequests()
        listRequestTask?.cancel()
        newerRequestTask?.cancel()
        listRequestTask = nil
        listRequestToken = nil
        newerRequestTask = nil
        newerRequestToken = nil
        isLoading = false
    }

    @MainActor
    private func handlePostContentNotification(_ notification: Notification) {
        guard let event = PostContentEventCenter.event(from: notification) else { return }
        applyPostContentAction(
            BookmarkFeedIntegration.action(
                for: event,
                edges: edges,
                eventGeneration: requestCoordinator.epoch,
                activeGeneration: requestCoordinator.epoch
            )
        )
    }

    private func shouldLoadMore(afterAppearing edge: HackersPub.BookmarksQuery.Data.Bookmarks.Edge) -> Bool {
        guard hasNextPage, !isLoading else { return false }
        return edge.node.id == edges.last?.node.id
    }

    @discardableResult
    private func startListRequest(
        reset: Bool,
        cachePolicy: CachePolicy.Query.SingleResponse
    ) -> Task<Void, Never> {
        listRequestTask?.cancel()
        newerRequestTask?.cancel()
        let filter = selectedFilter
        let kind: BookmarkFilterRequestKind = reset
            ? (hasLoadedInitial ? .refresh : .initial)
            : .older
        let token = requestCoordinator.begin(kind)
        listRequestToken = token
        newerRequestToken = nil
        isLoading = true
        errorMessage = nil

        let task = Task { @MainActor in
            await performListRequest(
                reset: reset,
                cachePolicy: cachePolicy,
                filter: filter,
                token: token
            )
        }
        listRequestTask = task
        return task
    }

    private func performListRequest(
        reset: Bool,
        cachePolicy: CachePolicy.Query.SingleResponse,
        filter: BookmarkFilter,
        token: BookmarkFilterRequestToken
    ) async {
        guard requestCoordinator.isCurrent(token) else { return }
        var wasCancelled = false
        defer {
            if listRequestToken == token, requestCoordinator.finish(token) {
                isLoading = false
                listRequestTask = nil
                listRequestToken = nil
                if !wasCancelled {
                    hasLoadedInitial = true
                }
            }
        }

        let after: GraphQLNullable<String> = reset ? nil : endCursor.map { .some($0) } ?? nil

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.BookmarksQuery(
                    after: after,
                    before: nil,
                    first: 20,
                    last: nil,
                    postType: filter.postType
                ),
                cachePolicy: cachePolicy
            )

            let connection = response.data?.bookmarks
            let incoming = connection?.edges ?? []
            guard requestCoordinator.isCurrent(token), !Task.isCancelled else {
                wasCancelled = true
                return
            }

            if reset {
                edges = BookmarkFeedIntegration.normalizedPage(incoming)
                hasPreviousPage = false
                pendingNewerCursor = nil
            } else {
                BookmarkFeedIntegration.append(incoming, to: &edges)
                hasPreviousPage = false
            }

            hasNextPage = connection?.pageInfo.hasNextPage ?? false
            startCursor = connection?.pageInfo.startCursor
            endCursor = connection?.pageInfo.endCursor
        } catch is CancellationError {
            wasCancelled = true
        } catch {
            guard requestCoordinator.isCurrent(token), !Task.isCancelled else {
                wasCancelled = true
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func loadNewerBookmarks() async {
        guard !isLoading else { return }
        if let task = startNewerRequest() {
            await task.value
        }
    }

    private func startNewerRequest() -> Task<Void, Never>? {
        guard let cursor = pendingNewerCursor ?? startCursor else { return nil }
        listRequestTask?.cancel()
        newerRequestTask?.cancel()
        let filter = selectedFilter
        let token = requestCoordinator.begin(.newer)
        listRequestToken = nil
        newerRequestToken = token
        isLoading = true
        errorMessage = nil

        let task = Task { @MainActor in
            await performNewerRequest(cursor: cursor, filter: filter, token: token)
        }
        newerRequestTask = task
        return task
    }

    private func performNewerRequest(
        cursor: String,
        filter: BookmarkFilter,
        token: BookmarkFilterRequestToken
    ) async {
        guard requestCoordinator.isCurrent(token) else { return }
        defer {
            if newerRequestToken == token, requestCoordinator.finish(token) {
                isLoading = false
                newerRequestTask = nil
                newerRequestToken = nil
            }
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.BookmarksQuery(
                    after: nil,
                    before: .some(cursor),
                    first: nil,
                    last: 20,
                    postType: filter.postType
                ),
                cachePolicy: .networkOnly
            )
            guard requestCoordinator.isCurrent(token), !Task.isCancelled else {
                return
            }
            guard let connection = response.data?.bookmarks else { return }
            mergeNewerPage(
                connection.edges,
                nextCursor: connection.pageInfo.startCursor,
                hasNextPage: connection.pageInfo.hasPreviousPage
            )
            if let newStartCursor = edges.first?.cursor {
                startCursor = newStartCursor
            }
            if endCursor == nil {
                endCursor = connection.pageInfo.endCursor
            }
        } catch is CancellationError {
            return
        } catch {
            guard requestCoordinator.isCurrent(token), !Task.isCancelled else {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func mergeNewerPage(
        _ incoming: [HackersPub.BookmarksQuery.Data.Bookmarks.Edge],
        nextCursor: String?,
        hasNextPage: Bool
    ) {
        let merge = BookmarkFeedIntegration.mergingNewerPage(
            incoming,
            into: edges,
            nextCursor: nextCursor,
            hasNextPage: hasNextPage
        )
        BookmarkFeedIntegration.applyScrollAnchorAction(
            for: merge, policy: &scrollAnchorPolicy, restoration: &scrollRestoreRequest,
            viewport: scrollViewport, existing: edges
        )
        edges = merge.edges
        pendingNewerCursor = merge.pendingNewerCursor
        hasPreviousPage = merge.hasPreviousPage
    }
}
