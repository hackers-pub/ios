import SwiftUI
@preconcurrency import Apollo

private enum BookmarkFilter: String, CaseIterable, Identifiable {
    case all
    case articles
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return NSLocalizedString("bookmarks.filter.all", comment: "All bookmarks filter")
        case .articles:
            return NSLocalizedString("bookmarks.filter.articles", comment: "Article bookmarks filter")
        case .notes:
            return NSLocalizedString("bookmarks.filter.notes", comment: "Note bookmarks filter")
        }
    }

    var postType: GraphQLNullable<GraphQLEnum<HackersPub.PostType>> {
        switch self {
        case .all:
            return nil
        case .articles:
            return .some(.case(.article))
        case .notes:
            return .some(.case(.note))
        }
    }
}

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
    @State private var fetchGeneration = 0
    @State private var showingSettings = false
    @State private var showingArticleEditor = false
    @State private var showingArticleDrafts = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
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
                        Task {
                            await fetchBookmarks(reset: true, cachePolicy: .networkOnly)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if hasLoadedInitial && edges.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString("bookmarks.empty.title", comment: "No bookmarks title"),
                    systemImage: "bookmark",
                    description: Text(NSLocalizedString("bookmarks.empty.description", comment: "No bookmarks description"))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if hasPreviousPage && !edges.isEmpty {
                            LoadNewerItemsRow(isLoading: isLoading) {
                                Task {
                                    await loadNewerBookmarks()
                                }
                            }
                            Divider()
                        }

                        ForEach(edges, id: \.cursor) { edge in
                            bookmarkRow(edge)

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
                                    await loadMore()
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    await refreshBookmarks()
                }
            }
        }
        .navigationTitle(NSLocalizedString("bookmarks.title", comment: "Bookmarks navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                ViewerProfileButton()

                Button {
                    showingSettings = true
                } label: {
                    Label(NSLocalizedString("common.settings", comment: "Settings button"), systemImage: "gear")
                }
            }

            ToolbarItem(placement: .principal) {
                Picker(NSLocalizedString("bookmarks.filter", comment: "Bookmarks filter picker"), selection: $selectedFilter) {
                    ForEach(BookmarkFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingComposeView = true
                    } label: {
                        Label(NSLocalizedString("common.newPost", comment: "New note button"), systemImage: "square.and.pencil")
                    }
                    Button {
                        showingArticleEditor = true
                    } label: {
                        Label(NSLocalizedString("article.new", comment: "New article"), systemImage: "doc.badge.plus")
                    }
                    Button {
                        showingArticleDrafts = true
                    } label: {
                        Label(NSLocalizedString("article.drafts", comment: "Article drafts"), systemImage: "tray.full")
                    }
                } label: {
                    Label(NSLocalizedString("common.compose", comment: "Compose menu"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingArticleEditor) {
            ArticleEditorView {
                showingArticleEditor = false
                Task {
                    await fetchBookmarks(reset: true, cachePolicy: .networkOnly)
                }
            }
        }
        .sheet(isPresented: $showingArticleDrafts) {
            ArticleDraftListView()
        }
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .profile(let handle):
                ActorProfileViewWrapper(handle: handle)
            case .post(let id):
                PostDetailView(postId: id)
            case .newsStory(let id):
                NewsStoryDetailView(storyId: id)
            }
        }
        .task {
            guard !hasLoadedInitial else { return }
            await fetchBookmarks(reset: true, cachePolicy: .networkFirst)
        }
        .onChange(of: selectedFilter) {
            reset()
            Task {
                await fetchBookmarks(reset: true, cachePolicy: .networkOnly)
            }
        }
    }

    private func reset() {
        fetchGeneration += 1
        edges = []
        hasLoadedInitial = false
        hasPreviousPage = false
        hasNextPage = false
        startCursor = nil
        endCursor = nil
        pendingNewerCursor = nil
        errorMessage = nil
    }

    private func loadMore() async {
        guard hasNextPage, endCursor != nil else { return }
        await fetchBookmarks(reset: false, cachePolicy: .networkFirst)
    }

    private func refreshBookmarks() async {
        guard !isLoading else { return }
        if edges.isEmpty || startCursor == nil {
            await fetchBookmarks(reset: true, cachePolicy: .networkOnly)
            return
        }

        let shouldShowLoading = edges.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        errorMessage = nil
        defer {
            if shouldShowLoading {
                isLoading = false
            }
        }

        do {
            try await fetchNewerBookmarks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func bookmarkRow(_ edge: HackersPub.BookmarksQuery.Data.Bookmarks.Edge) -> some View {
        PostView(
            post: edge.node,
            showAuthor: true,
            disableNavigation: false,
            enableSneakPeek: true,
            contentRenderMode: .lightweightText,
            onBookmarkChanged: handleBookmarkChange
        )
        .padding()
        .onAppear {
            guard shouldLoadMore(afterAppearing: edge) else { return }

            Task {
                await loadMore()
            }
        }
    }

    private func handleBookmarkChange(postID: String, isBookmarked: Bool) {
        guard !isBookmarked else { return }

        edges.removeAll { edge in
            edge.node.id == postID || edge.node.sharedPost?.id == postID
        }
    }

    private func shouldLoadMore(afterAppearing edge: HackersPub.BookmarksQuery.Data.Bookmarks.Edge) -> Bool {
        guard hasNextPage, !isLoading else { return false }
        return edge.cursor == edges.last?.cursor
    }

    private func fetchBookmarks(reset: Bool, cachePolicy: CachePolicy.Query.SingleResponse) async {
        guard reset || !isLoading else { return }
        if reset {
            fetchGeneration += 1
        }
        let generation = fetchGeneration

        isLoading = true
        errorMessage = nil
        defer {
            if generation == fetchGeneration {
                isLoading = false
                hasLoadedInitial = true
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
                    postType: selectedFilter.postType
                ),
                cachePolicy: cachePolicy
            )

            let connection = response.data?.bookmarks
            let incoming = connection?.edges ?? []
            guard generation == fetchGeneration else { return }

            if reset {
                edges = incoming
                hasPreviousPage = false
                pendingNewerCursor = nil
            } else {
                appendUnique(incoming)
                hasPreviousPage = false
            }

            hasNextPage = connection?.pageInfo.hasNextPage ?? false
            startCursor = connection?.pageInfo.startCursor
            endCursor = connection?.pageInfo.endCursor
        } catch {
            guard generation == fetchGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadNewerBookmarks() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await fetchNewerBookmarks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchNewerBookmarks() async throws {
        guard let cursor = pendingNewerCursor ?? startCursor else { return }

        let response = try await apolloClient.fetch(
            query: HackersPub.BookmarksQuery(
                after: nil,
                before: .some(cursor),
                first: nil,
                last: 20,
                postType: selectedFilter.postType
            ),
            cachePolicy: .networkOnly
        )
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
    }

    private func prependUnique(_ incoming: [HackersPub.BookmarksQuery.Data.Bookmarks.Edge]) {
        let existingIDs = Set(edges.map { $0.node.id })
        edges = incoming.filter { !existingIDs.contains($0.node.id) } + edges
    }

    private func appendUnique(_ incoming: [HackersPub.BookmarksQuery.Data.Bookmarks.Edge]) {
        let existingIDs = Set(edges.map { $0.node.id })
        edges.append(contentsOf: incoming.filter { !existingIDs.contains($0.node.id) })
    }

    private func mergeNewerPage(
        _ incoming: [HackersPub.BookmarksQuery.Data.Bookmarks.Edge],
        nextCursor: String?,
        hasNextPage: Bool
    ) {
        guard !incoming.isEmpty else {
            hasPreviousPage = false
            pendingNewerCursor = nil
            return
        }

        prependUnique(incoming)
        pendingNewerCursor = hasNextPage ? nextCursor : nil
        hasPreviousPage = hasNextPage && nextCursor != nil
    }
}
