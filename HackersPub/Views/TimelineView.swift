import SwiftUI
@preconcurrency import Apollo

typealias Post = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node
typealias LocalPost = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.Actor: ActorProtocol {}
extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.LastSharer: ActorProtocol {}
extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge {
    var timelineListID: String {
        "\(node.id)-\(added)"
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost? { nil }
    var quotedPost: HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.Actor: ActorProtocol {}
extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.LastSharer: ActorProtocol {}
extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge {
    var timelineListID: String {
        "\(node.id)-\(added)"
    }
}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost? { nil }
    var quotedPost: HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost.Medium: MediaProtocol {}

typealias PersonalPost = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.Actor: ActorProtocol {}
extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.LastSharer: ActorProtocol {}
extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge {
    var timelineListID: String {
        "\(node.id)-\(added)"
    }
}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost? { nil }
    var quotedPost: HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        return __typename == "Article"
    }
    
    var mentionedHandles: [String] {
        return self.mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.QuotedPost.Medium: MediaProtocol {}

struct TimelineView: View {
    @Binding var showingComposeView: Bool
    @State private var edges: [HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge] = []
    @State private var hasLoadedInitial = false
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var shouldRefresh = false
    @State private var showingSettings = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .global)) {
            Group {
                if isLoading && edges.isEmpty {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(edges, id: \.timelineListID) { edge in
                                PostView(
                                    post: edge.node,
                                    timelineSharer: edge.lastSharer,
                                    timelineAdded: edge.added,
                                    showAuthor: true,
                                    enableSneakPeek: true,
                                    contentRenderMode: .lightweightText
                                )
                                    .padding()
                                    .id(edge.timelineListID)
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
                        }
                        .padding(.top, 8)
                    }
                    .id(edges.first?.timelineListID ?? "timeline-empty")
                    .refreshable {
                        await refreshPosts()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("timeline.fediverse", comment: "Fediverse navigation title"))
            .navigationBarTitleDisplayMode(.inline)
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

                if authManager.isAuthenticated {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingComposeView = true
                        } label: {
                            Label(NSLocalizedString("common.newPost", comment: "New post button"), systemImage: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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

    private func fetchPosts() async {
        // Don't show loading initially if we have cached data
        if edges.isEmpty {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil), cachePolicy: .networkFirst)
            edges = response.data?.publicTimeline.edges ?? []
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: .some(cursor)))
            edges.append(contentsOf: response.data?.publicTimeline.edges ?? [])
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }

    private func refreshPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetchAfterClearingCache(query: HackersPub.PublicTimelineQuery(after: nil))
            edges = response.data?.publicTimeline.edges ?? []
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }
}

struct PersonalTimelineView: View {
    @Binding var showingComposeView: Bool
    @State private var edges: [HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge] = []
    @State private var hasLoadedInitial = false
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var shouldRefresh = false
    @State private var showingSettings = false
    @State private var showingArticleEditor = false
    @State private var showingArticleDrafts = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .timeline)) {
            Group {
                if isLoading && edges.isEmpty {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(edges, id: \.timelineListID) { edge in
                                PostView(
                                    post: edge.node,
                                    timelineSharer: edge.lastSharer,
                                    timelineAdded: edge.added,
                                    showAuthor: true,
                                    enableSneakPeek: true,
                                    contentRenderMode: .lightweightText
                                )
                                    .padding()
                                    .id(edge.timelineListID)
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
                        }
                        .padding(.top, 8)
                    }
                    .id(edges.first?.timelineListID ?? "personal-timeline-empty")
                    .refreshable {
                        await refreshPosts()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav.timeline", comment: "Timeline navigation title"))
            .navigationBarTitleDisplayMode(.inline)
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

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingComposeView = true
                        } label: {
                            Label(NSLocalizedString("common.newPost", comment: "New post button"), systemImage: "square.and.pencil")
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
                        await refreshPosts()
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
                }
            }
        }
    }

    private func fetchPosts() async {
        // Don't show loading initially if we have cached data
        if edges.isEmpty {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PersonalTimelineQuery(after: nil), cachePolicy: .networkFirst)
            edges = response.data?.personalTimeline.edges ?? []
            hasNextPage = response.data?.personalTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.personalTimeline.pageInfo.endCursor
        } catch {}
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PersonalTimelineQuery(after: .some(cursor)))
            edges.append(contentsOf: response.data?.personalTimeline.edges ?? [])
            hasNextPage = response.data?.personalTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.personalTimeline.pageInfo.endCursor
        } catch {}
    }

    private func refreshPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetchAfterClearingCache(query: HackersPub.PersonalTimelineQuery(after: nil))
            edges = response.data?.personalTimeline.edges ?? []
            hasNextPage = response.data?.personalTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.personalTimeline.pageInfo.endCursor
        } catch {}
    }
}

struct LocalTimelineView: View {
    @Binding var showingComposeView: Bool
    @State private var edges: [HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge] = []
    @State private var hasLoadedInitial = false
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var shouldRefresh = false
    @State private var showingSettings = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .local)) {
            Group {
                if isLoading && edges.isEmpty {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(edges, id: \.timelineListID) { edge in
                                PostView(
                                    post: edge.node,
                                    timelineSharer: edge.lastSharer,
                                    timelineAdded: edge.added,
                                    showAuthor: true,
                                    enableSneakPeek: true,
                                    contentRenderMode: .lightweightText
                                )
                                    .padding()
                                    .id(edge.timelineListID)
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
                        }
                        .padding(.top, 8)
                    }
                    .id(edges.first?.timelineListID ?? "local-timeline-empty")
                    .refreshable {
                        await refreshPosts()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("timeline.hackersPub", comment: "Hackers' Pub navigation title"))
            .navigationBarTitleDisplayMode(.inline)
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

                if authManager.isAuthenticated {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingComposeView = true
                        } label: {
                            Label(NSLocalizedString("common.newPost", comment: "New post button"), systemImage: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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

    private func fetchPosts() async {
        // Don't show loading initially if we have cached data
        if edges.isEmpty {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil), cachePolicy: .networkFirst)
            edges = response.data?.publicTimeline.edges ?? []
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: .some(cursor)))
            edges.append(contentsOf: response.data?.publicTimeline.edges ?? [])
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }

    private func refreshPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetchAfterClearingCache(query: HackersPub.LocalTimelineQuery(after: nil))
            edges = response.data?.publicTimeline.edges ?? []
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }
}

struct ActorProfileViewWrapper: View {
    let handle: String
    @State private var actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                ContentUnavailableView(
                    NSLocalizedString("common.error", comment: "Error title"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let actor = actor {
                ActorProfileView(actor: actor)
            }
        }
        .task {
            await fetchProfile()
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func fetchProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Always fetch from network to get fresh data
            let response = try await apolloClient.fetch(query: HackersPub.ActorByHandleQuery(handle: handle, after: nil), cachePolicy: .networkOnly)
            if let actorData = response.data?.actorByHandle {
                actor = actorData
            } else {
                errorMessage = "Profile not found"
            }
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
    }
}
