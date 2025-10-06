import SwiftUI
@preconcurrency import Apollo

typealias Post = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node
typealias LocalPost = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.EngagementStats

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.EngagementStats

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Medium: MediaProtocol {}

typealias PersonalPost = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.EngagementStats

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.Actor: ActorProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost
    typealias EngagementStatsType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost? { nil }

    var isArticle: Bool {
        // Temporarily disabled - just show all posts as regular posts
        return false
    }
}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.Medium: MediaProtocol {}

struct TimelineView: View {
    @Binding var showingComposeView: Bool
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var shouldRefresh = false
    @State private var showingSettings = false

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && posts.isEmpty {
                    ProgressView()
                } else {
                    List {
                        ForEach(posts, id: \.id) { post in
                            PostView(post: post)
                                .onAppear {
                                    if post.id == posts.last?.id && hasNextPage && !isLoading {
                                        Task {
                                            await loadMore()
                                        }
                                    }
                                }
                        }

                        if isLoading && !posts.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fediverse")
            .refreshable {
                await refreshPosts()
            }
            .task {
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
                        Label("Settings", systemImage: "gear")
                    }
                }

                if showingComposeView != false || showingComposeView == false {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingComposeView = true
                        } label: {
                            Label("New Post", systemImage: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private func fetchPosts() async {
        print("🔵 TimelineView: Starting to fetch posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            print("🔵 TimelineView: Calling apolloClient.fetch...")
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil))
            print("🔵 TimelineView: Got response, data exists: \(response.data != nil)")

            // Check for GraphQL errors
            if let errors = response.errors, !errors.isEmpty {
                print("⚠️ TimelineView: GraphQL errors present:")
                for error in errors {
                    print("   - \(error.message ?? "Unknown error")")
                    if let extensions = error["extensions"] as? [String: Any] {
                        print("   Extensions: \(extensions)")
                    }
                }
            }

            print("🔵 TimelineView: Edges count: \(response.data?.publicTimeline.edges.count ?? 0)")

            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            print("🔵 TimelineView: Mapped posts count: \(fetchedPosts.count)")

            if let firstPost = fetchedPosts.first {
                print("🔵 TimelineView: First post ID: \(firstPost.id)")
                print("🔵 TimelineView: First post name: \(firstPost.name ?? "nil")")
                print("🔵 TimelineView: First post summary: \(firstPost.summary ?? "nil")")
                print("🔵 TimelineView: First post content length: \(firstPost.content.count)")
            }

            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            print("🔵 TimelineView: Set posts array, count: \(posts.count)")
        } catch {
            print("❌ TimelineView: Error fetching posts: \(error)")
            print("❌ TimelineView: Error details: \(String(describing: error))")
            print("❌ TimelineView: Error type: \(type(of: error))")
        }
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: .some(cursor)))
            let newPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts.append(contentsOf: newPosts)
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {
            print("Error loading more posts: \(error)")
        }
    }

    private func refreshPosts() async {
        print("🔵 TimelineView: Refreshing posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            // Clear cache and fetch fresh data
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil))
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {
            print("❌ TimelineView: Error refreshing posts: \(error)")
        }
    }
}

struct PersonalTimelineView: View {
    @Binding var showingComposeView: Bool
    @State private var posts: [PersonalPost] = []
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var shouldRefresh = false
    @State private var showingSettings = false

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && posts.isEmpty {
                    ProgressView()
                } else {
                    List {
                        ForEach(posts, id: \.id) { post in
                            PostView(post: post)
                                .onAppear {
                                    if post.id == posts.last?.id && hasNextPage && !isLoading {
                                        Task {
                                            await loadMore()
                                        }
                                    }
                                }
                        }

                        if isLoading && !posts.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Timeline")
            .refreshable {
                await refreshPosts()
            }
            .task {
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
                        Label("Settings", systemImage: "gear")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingComposeView = true
                    } label: {
                        Label("New Post", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private func fetchPosts() async {
        print("🟢 PersonalTimelineView: Starting to fetch posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            print("🟢 PersonalTimelineView: Calling apolloClient.fetch...")
            let response = try await apolloClient.fetch(query: HackersPub.PersonalTimelineQuery(after: nil))
            print("🟢 PersonalTimelineView: Got response, data exists: \(response.data != nil)")

            // Check for GraphQL errors
            if let errors = response.errors, !errors.isEmpty {
                print("⚠️ PersonalTimelineView: GraphQL errors present:")
                for error in errors {
                    print("   - \(error.message ?? "Unknown error")")
                    if let extensions = error["extensions"] as? [String: Any] {
                        print("   Extensions: \(extensions)")
                    }
                }
            }

            print("🟢 PersonalTimelineView: Edges count: \(response.data?.personalTimeline.edges.count ?? 0)")

            let fetchedPosts = response.data?.personalTimeline.edges.map { $0.node } ?? []
            print("🟢 PersonalTimelineView: Mapped posts count: \(fetchedPosts.count)")

            if let firstPost = fetchedPosts.first {
                print("🟢 PersonalTimelineView: First post ID: \(firstPost.id)")
                print("🟢 PersonalTimelineView: First post content length: \(firstPost.content.count)")
            }

            posts = fetchedPosts
            hasNextPage = response.data?.personalTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.personalTimeline.pageInfo.endCursor
            print("🟢 PersonalTimelineView: Set posts array, count: \(posts.count)")
        } catch {
            print("❌ PersonalTimelineView: Error fetching posts: \(error)")
            print("❌ PersonalTimelineView: Error details: \(String(describing: error))")
            print("❌ PersonalTimelineView: Error type: \(type(of: error))")
        }
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PersonalTimelineQuery(after: .some(cursor)))
            let newPosts = response.data?.personalTimeline.edges.map { $0.node } ?? []
            posts.append(contentsOf: newPosts)
            hasNextPage = response.data?.personalTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.personalTimeline.pageInfo.endCursor
        } catch {
            print("Error loading more posts: \(error)")
        }
    }

    private func refreshPosts() async {
        print("🟢 PersonalTimelineView: Refreshing posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            // Clear cache and fetch fresh data
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.PersonalTimelineQuery(after: nil))
            let fetchedPosts = response.data?.personalTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.personalTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.personalTimeline.pageInfo.endCursor
        } catch {
            print("❌ PersonalTimelineView: Error refreshing posts: \(error)")
        }
    }
}

struct LocalTimelineView: View {
    @Binding var showingComposeView: Bool
    @State private var posts: [LocalPost] = []
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var shouldRefresh = false
    @State private var showingSettings = false

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && posts.isEmpty {
                    ProgressView()
                } else {
                    List {
                        ForEach(posts, id: \.id) { post in
                            PostView(post: post)
                                .onAppear {
                                    if post.id == posts.last?.id && hasNextPage && !isLoading {
                                        Task {
                                            await loadMore()
                                        }
                                    }
                                }
                        }

                        if isLoading && !posts.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hackers' Pub")
            .refreshable {
                await refreshPosts()
            }
            .task {
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
                        Label("Settings", systemImage: "gear")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingComposeView = true
                    } label: {
                        Label("New Post", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private func fetchPosts() async {
        print("🟠 LocalTimelineView: Starting to fetch posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            print("🟠 LocalTimelineView: Calling apolloClient.fetch...")
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil))
            print("🟠 LocalTimelineView: Got response, data exists: \(response.data != nil)")

            // Check for GraphQL errors
            if let errors = response.errors, !errors.isEmpty {
                print("⚠️ LocalTimelineView: GraphQL errors present:")
                for error in errors {
                    print("   - \(error.message ?? "Unknown error")")
                    if let extensions = error["extensions"] as? [String: Any] {
                        print("   Extensions: \(extensions)")
                    }
                }
            }

            print("🟠 LocalTimelineView: Edges count: \(response.data?.publicTimeline.edges.count ?? 0)")

            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            print("🟠 LocalTimelineView: Mapped posts count: \(fetchedPosts.count)")

            if let firstPost = fetchedPosts.first {
                print("🟠 LocalTimelineView: First post ID: \(firstPost.id)")
                print("🟠 LocalTimelineView: First post content length: \(firstPost.content.count)")
            }

            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            print("🟠 LocalTimelineView: Set posts array, count: \(posts.count)")
        } catch {
            print("❌ LocalTimelineView: Error fetching posts: \(error)")
            print("❌ LocalTimelineView: Error details: \(String(describing: error))")
            print("❌ LocalTimelineView: Error type: \(type(of: error))")
        }
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: .some(cursor)))
            let newPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts.append(contentsOf: newPosts)
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {
            print("Error loading more posts: \(error)")
        }
    }

    private func refreshPosts() async {
        print("🟠 LocalTimelineView: Refreshing posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            // Clear cache and fetch fresh data
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil))
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {
            print("❌ LocalTimelineView: Error refreshing posts: \(error)")
        }
    }
}

