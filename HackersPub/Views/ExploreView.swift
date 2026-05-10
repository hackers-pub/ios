import SwiftUI
@preconcurrency import Apollo

enum ExploreScope: CaseIterable {
    case local
    case global

    var displayName: String {
        switch self {
        case .local:
            return NSLocalizedString("explore.scope.local", comment: "Local scope")
        case .global:
            return NSLocalizedString("explore.scope.global", comment: "Global scope")
        }
    }
}

struct ExploreView: View {
    @Binding var showingComposeView: Bool
    @State private var selectedScope: ExploreScope = .local
    @State private var showingSettings = false
    @State private var showingArticleEditor = false
    @State private var showingArticleDrafts = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .explore)) {
            Group {
                switch selectedScope {
                case .local:
                    LocalTimelineContent(showingComposeView: $showingComposeView)
                case .global:
                    GlobalTimelineContent(showingComposeView: $showingComposeView)
                }
            }
            .navigationTitle(NSLocalizedString("nav.explore", comment: "Explore navigation title"))
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
                    Picker(NSLocalizedString("explore.scope", comment: "Scope picker"), selection: $selectedScope) {
                        ForEach(ExploreScope.allCases, id: \.self) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if authManager.isAuthenticated {
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
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingArticleEditor) {
                ArticleEditorView {
                    showingArticleEditor = false
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
                }
            }
        }
    }
}

// Extracted LocalTimeline content without NavigationStack
struct LocalTimelineContent: View {
    @Binding var showingComposeView: Bool
    @State private var edges: [HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge] = []
    @State private var hasLoadedInitial = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasPreviousPage = false
    @State private var hasNextPage = false
    @State private var startCursor: String?
    @State private var endCursor: String?
    @State private var pendingNewerCursor: String?
    @State private var shouldRefresh = false

    var body: some View {
        Group {
            if isLoading && edges.isEmpty {
                ProgressView()
            } else if let errorMessage, edges.isEmpty {
                LoadFailureView(message: errorMessage) {
                    Task {
                        await fetchPosts()
                    }
                }
            } else {
                ScrollView {
                LazyVStack(spacing: 0) {
                    if hasPreviousPage && !edges.isEmpty {
                        LoadNewerItemsRow(isLoading: isLoading) {
                            Task {
                                await loadNewerPosts()
                            }
                        }
                        Divider()
                    }

                    ForEach(edges, id: \.timelineListID) { edge in
                            PostView(
                                post: edge.node,
                                timelineSharer: edge.lastSharer,
                                timelineAdded: edge.added,
                                enableSneakPeek: true,
                                contentRenderMode: .lightweightText
                            )
                                .padding()
                                .onAppear {
                                    if edge.cursor == edges.last?.cursor && hasNextPage && !isLoading {
                                        Task {
                                            await loadMore()
                                        }
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
                                    await refreshPosts()
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            await refreshPosts()
        }
        .task {
            guard !hasLoadedInitial else { return }
            hasLoadedInitial = true
            await fetchPosts()
        }
        .onChange(of: shouldRefresh) { _, newValue in
            if newValue {
                Task {
                    await refreshPosts()
                    shouldRefresh = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshTimeline"))) { _ in
            shouldRefresh = true
        }
    }

    private func fetchPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.LocalTimelineQuery(after: nil, before: nil, first: 20, last: nil),
                cachePolicy: .networkFirst
            )
            edges = response.data?.publicTimeline.edges ?? []
            hasPreviousPage = false
            pendingNewerCursor = nil
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            startCursor = response.data?.publicTimeline.pageInfo.startCursor
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.LocalTimelineQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                cachePolicy: .networkOnly
            )
            appendUnique(response.data?.publicTimeline.edges ?? [])
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPosts() async {
        let shouldShowLoading = edges.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        defer {
            if shouldShowLoading {
                isLoading = false
            }
        }

        do {
            if edges.isEmpty || startCursor == nil {
                let response = try await apolloClient.fetch(
                    query: HackersPub.LocalTimelineQuery(after: nil, before: nil, first: 20, last: nil),
                    cachePolicy: .networkOnly
                )
                edges = response.data?.publicTimeline.edges ?? []
                hasPreviousPage = false
                pendingNewerCursor = nil
                hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
                startCursor = response.data?.publicTimeline.pageInfo.startCursor
                endCursor = response.data?.publicTimeline.pageInfo.endCursor
            } else {
                try await fetchNewerPosts()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadNewerPosts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await fetchNewerPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchNewerPosts() async throws {
        guard let cursor = pendingNewerCursor ?? startCursor else { return }

        let response = try await apolloClient.fetch(
            query: HackersPub.LocalTimelineQuery(
                after: nil,
                before: .some(cursor),
                first: nil,
                last: 20
            ),
            cachePolicy: .networkOnly
        )
        guard let connection = response.data?.publicTimeline else { return }
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

    private func prependUnique(_ incoming: [HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge]) {
        let existingIDs = Set(edges.map(\.timelineListID))
        edges = incoming.filter { !existingIDs.contains($0.timelineListID) } + edges
    }

    private func appendUnique(_ incoming: [HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge]) {
        let existingIDs = Set(edges.map(\.timelineListID))
        edges.append(contentsOf: incoming.filter { !existingIDs.contains($0.timelineListID) })
    }

    private func mergeNewerPage(
        _ incoming: [HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge],
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

// Extracted GlobalTimeline content without NavigationStack
struct GlobalTimelineContent: View {
    @Binding var showingComposeView: Bool
    @State private var edges: [HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge] = []
    @State private var hasLoadedInitial = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasPreviousPage = false
    @State private var hasNextPage = false
    @State private var startCursor: String?
    @State private var endCursor: String?
    @State private var pendingNewerCursor: String?
    @State private var shouldRefresh = false

    var body: some View {
        Group {
            if isLoading && edges.isEmpty {
                ProgressView()
            } else if let errorMessage, edges.isEmpty {
                LoadFailureView(message: errorMessage) {
                    Task {
                        await fetchPosts()
                    }
                }
            } else {
                ScrollView {
                LazyVStack(spacing: 0) {
                    if hasPreviousPage && !edges.isEmpty {
                        LoadNewerItemsRow(isLoading: isLoading) {
                            Task {
                                await loadNewerPosts()
                            }
                        }
                        Divider()
                    }

                    ForEach(edges, id: \.timelineListID) { edge in
                            PostView(
                                post: edge.node,
                                timelineSharer: edge.lastSharer,
                                timelineAdded: edge.added,
                                enableSneakPeek: true,
                                contentRenderMode: .lightweightText
                            )
                                .padding()
                                .onAppear {
                                    if edge.cursor == edges.last?.cursor && hasNextPage && !isLoading {
                                        Task {
                                            await loadMore()
                                        }
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
                                    await refreshPosts()
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            await refreshPosts()
        }
        .task {
            guard !hasLoadedInitial else { return }
            hasLoadedInitial = true
            await fetchPosts()
        }
        .onChange(of: shouldRefresh) { _, newValue in
            if newValue {
                Task {
                    await refreshPosts()
                    shouldRefresh = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshTimeline"))) { _ in
            shouldRefresh = true
        }
    }

    private func fetchPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.PublicTimelineQuery(after: nil, before: nil, first: 20, last: nil),
                cachePolicy: .networkFirst
            )
            edges = response.data?.publicTimeline.edges ?? []
            hasPreviousPage = false
            pendingNewerCursor = nil
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            startCursor = response.data?.publicTimeline.pageInfo.startCursor
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.PublicTimelineQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                cachePolicy: .networkOnly
            )
            appendUnique(response.data?.publicTimeline.edges ?? [])
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPosts() async {
        let shouldShowLoading = edges.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        defer {
            if shouldShowLoading {
                isLoading = false
            }
        }

        do {
            if edges.isEmpty || startCursor == nil {
                let response = try await apolloClient.fetch(
                    query: HackersPub.PublicTimelineQuery(after: nil, before: nil, first: 20, last: nil),
                    cachePolicy: .networkOnly
                )
                edges = response.data?.publicTimeline.edges ?? []
                hasPreviousPage = false
                pendingNewerCursor = nil
                hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
                startCursor = response.data?.publicTimeline.pageInfo.startCursor
                endCursor = response.data?.publicTimeline.pageInfo.endCursor
            } else {
                try await fetchNewerPosts()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadNewerPosts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await fetchNewerPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchNewerPosts() async throws {
        guard let cursor = pendingNewerCursor ?? startCursor else { return }

        let response = try await apolloClient.fetch(
            query: HackersPub.PublicTimelineQuery(
                after: nil,
                before: .some(cursor),
                first: nil,
                last: 20
            ),
            cachePolicy: .networkOnly
        )
        guard let connection = response.data?.publicTimeline else { return }
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

    private func prependUnique(_ incoming: [HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge]) {
        let existingIDs = Set(edges.map(\.timelineListID))
        edges = incoming.filter { !existingIDs.contains($0.timelineListID) } + edges
    }

    private func appendUnique(_ incoming: [HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge]) {
        let existingIDs = Set(edges.map(\.timelineListID))
        edges.append(contentsOf: incoming.filter { !existingIDs.contains($0.timelineListID) })
    }

    private func mergeNewerPage(
        _ incoming: [HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge],
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
