import SwiftUI

typealias BookmarkEdge = HackersPub.BookmarksQuery.Data.Bookmarks.Edge

struct BookmarkFeedContent: View {
    let edges: [BookmarkEdge]
    let isLoading: Bool
    let hasPreviousPage: Bool
    let errorMessage: String?
    let loadNewer: () async -> Void
    let loadMore: () async -> Void
    let refresh: () async -> Void
    let retry: () async -> Void
    let onBookmarkChanged: (String, Bool) -> Void
    let shouldLoadMore: (BookmarkEdge) -> Bool
    @Binding private var scrollViewport: FeedViewportSnapshot<String>
    @Binding private var scrollRestoreRequest: FeedScrollAnchorPolicy<String>.Restoration?

    init(
        edges: [BookmarkEdge],
        isLoading: Bool,
        hasPreviousPage: Bool,
        errorMessage: String?,
        loadNewer: @escaping () async -> Void,
        loadMore: @escaping () async -> Void,
        refresh: @escaping () async -> Void,
        retry: @escaping () async -> Void,
        onBookmarkChanged: @escaping (String, Bool) -> Void,
        shouldLoadMore: @escaping (BookmarkEdge) -> Bool,
        scrollViewport: Binding<FeedViewportSnapshot<String>>,
        scrollRestoreRequest: Binding<FeedScrollAnchorPolicy<String>.Restoration?>
    ) {
        self.edges = edges
        self.isLoading = isLoading
        self.hasPreviousPage = hasPreviousPage
        self.errorMessage = errorMessage
        self.loadNewer = loadNewer
        self.loadMore = loadMore
        self.refresh = refresh
        self.retry = retry
        self.onBookmarkChanged = onBookmarkChanged
        self.shouldLoadMore = shouldLoadMore
        _scrollViewport = scrollViewport
        _scrollRestoreRequest = scrollRestoreRequest
    }

    var body: some View {
        FeedAnchorScrollView(
            viewport: $scrollViewport,
            restoration: $scrollRestoreRequest
        ) {
            LazyVStack(spacing: 0) {
                if hasPreviousPage && !edges.isEmpty {
                    LoadNewerItemsRow(isLoading: isLoading) {
                        Task {
                            await loadNewer()
                        }
                    }
                    Divider()
                }

                ForEach(edges, id: \.node.id) { edge in
                    PostView(
                        post: edge.node,
                        showAuthor: true,
                        disableNavigation: false,
                        enableSneakPeek: true,
                        contentRenderMode: .lightweightText,
                        onBookmarkChanged: onBookmarkChanged
                    )
                    .padding()
                    .feedScrollAnchor(id: edge.node.id)
                    .id(edge.node.id)
                    .onAppear {
                        guard shouldLoadMore(edge) else { return }

                        Task {
                            await loadMore()
                        }
                    }

                    Divider()
                }

                if isLoading && !edges.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }

                if let errorMessage, !edges.isEmpty {
                    InlineLoadFailureView(message: errorMessage) {
                        Task {
                            await retry()
                        }
                    }
                }
            }
        }
        .refreshable {
            await refresh()
        }
    }
}
