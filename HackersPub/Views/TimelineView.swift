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
    @State private var scrollPosition: String?
    @State private var hasGap = false
    @State private var newPostsCount = 0
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: Bindable(navigationCoordinator).path) {
            Group {
                if isLoading && posts.isEmpty {
                    ProgressView()
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                                PostView(post: post, showAuthor: true)
                                    .id(post.id)
                                    .onAppear {
                                        if post.id == posts.last?.id && hasNextPage && !isLoading {
                                            Task {
                                                await loadMore()
                                            }
                                        }
                                    }

                                // Show gap button after last new post
                                if hasGap && index == newPostsCount - 1 {
                                    Button {
                                        Task {
                                            await loadGap()
                                        }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Label("Load newer posts", systemImage: "arrow.up.circle")
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
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
                        .scrollPosition(id: $scrollPosition)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("timeline.fediverse", comment: "Fediverse navigation title"))
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
                        Label(NSLocalizedString("common.settings", comment: "Settings button"), systemImage: "gear")
                    }
                }

                if showingComposeView != false || showingComposeView == false {
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
        if posts.isEmpty {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            // Fetch will use cache first, then network - Apollo's default behavior
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil))
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            newPostsCount = 0
        } catch {
            print("Error fetching posts: \(error)")
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
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil), cachePolicy: .networkOnly)
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []

            // Find new posts that aren't in the current list
            let existingIds = Set(posts.map { $0.id })
            let newPosts = fetchedPosts.filter { !existingIds.contains($0.id) }

            if !newPosts.isEmpty {
                // Check if there's a gap (fetched posts don't include our first post)
                if let firstCurrentPost = posts.first,
                   !fetchedPosts.contains(where: { $0.id == firstCurrentPost.id }) {
                    hasGap = true
                    newPostsCount = newPosts.count
                } else {
                    hasGap = false
                    newPostsCount = 0
                }

                // Prepend new posts
                posts = newPosts + posts
            } else {
                hasGap = false
                newPostsCount = 0
            }
        } catch {
            print("Error refreshing posts: \(error)")
        }
    }

    private func loadGap() async {
        hasGap = false
        newPostsCount = 0
        isLoading = true
        defer { isLoading = false }

        do {
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil))
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {
            print("Error loading gap: \(error)")
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
    @State private var scrollPosition: String?
    @State private var hasGap = false
    @State private var newPostsCount = 0
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: Bindable(navigationCoordinator).path) {
            Group {
                if isLoading && posts.isEmpty {
                    ProgressView()
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                                PostView(post: post, showAuthor: true)
                                    .id(post.id)
                                    .onAppear {
                                        if post.id == posts.last?.id && hasNextPage && !isLoading {
                                            Task {
                                                await loadMore()
                                            }
                                        }
                                    }

                                // Show gap button after last new post
                                if hasGap && index == newPostsCount - 1 {
                                    Button {
                                        Task {
                                            await loadGap()
                                        }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Label("Load newer posts", systemImage: "arrow.up.circle")
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
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
                        .scrollPosition(id: $scrollPosition)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav.timeline", comment: "Timeline navigation title"))
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
                        Label(NSLocalizedString("common.settings", comment: "Settings button"), systemImage: "gear")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingComposeView = true
                    } label: {
                        Label(NSLocalizedString("common.newPost", comment: "New post button"), systemImage: "square.and.pencil")
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
        if posts.isEmpty {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            // Fetch will use cache first, then network - Apollo's default behavior
            let response = try await apolloClient.fetch(query: HackersPub.PersonalTimelineQuery(after: nil))
            let fetchedPosts = response.data?.personalTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.personalTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.personalTimeline.pageInfo.endCursor
            newPostsCount = 0
        } catch {
            print("Error fetching posts: \(error)")
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
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PersonalTimelineQuery(after: nil), cachePolicy: .networkOnly)
            let fetchedPosts = response.data?.personalTimeline.edges.map { $0.node } ?? []

            // Find new posts that aren't in the current list
            let existingIds = Set(posts.map { $0.id })
            let newPosts = fetchedPosts.filter { !existingIds.contains($0.id) }

            if !newPosts.isEmpty {
                // Check if there's a gap (fetched posts don't include our first post)
                if let firstCurrentPost = posts.first,
                   !fetchedPosts.contains(where: { $0.id == firstCurrentPost.id }) {
                    hasGap = true
                    newPostsCount = newPosts.count
                } else {
                    hasGap = false
                    newPostsCount = 0
                }

                // Prepend new posts
                posts = newPosts + posts
            } else {
                hasGap = false
                newPostsCount = 0
            }
        } catch {
            print("Error refreshing posts: \(error)")
        }
    }

    private func loadGap() async {
        hasGap = false
        newPostsCount = 0
        isLoading = true
        defer { isLoading = false }

        do {
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.PersonalTimelineQuery(after: nil))
            let fetchedPosts = response.data?.personalTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.personalTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.personalTimeline.pageInfo.endCursor
        } catch {
            print("Error loading gap: \(error)")
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
    @State private var scrollPosition: String?
    @State private var hasGap = false
    @State private var newPostsCount = 0
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: Bindable(navigationCoordinator).path) {
            Group {
                if isLoading && posts.isEmpty {
                    ProgressView()
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                                PostView(post: post, showAuthor: true)
                                    .id(post.id)
                                    .onAppear {
                                        if post.id == posts.last?.id && hasNextPage && !isLoading {
                                            Task {
                                                await loadMore()
                                            }
                                        }
                                    }

                                // Show gap button after last new post
                                if hasGap && index == newPostsCount - 1 {
                                    Button {
                                        Task {
                                            await loadGap()
                                        }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Label("Load newer posts", systemImage: "arrow.up.circle")
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
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
                        .scrollPosition(id: $scrollPosition)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("timeline.hackersPub", comment: "Hackers' Pub navigation title"))
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
                        Label(NSLocalizedString("common.settings", comment: "Settings button"), systemImage: "gear")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingComposeView = true
                    } label: {
                        Label(NSLocalizedString("common.newPost", comment: "New post button"), systemImage: "square.and.pencil")
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
        if posts.isEmpty {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            // Fetch will use cache first, then network - Apollo's default behavior
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil))
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            newPostsCount = 0
        } catch {
            print("Error fetching posts: \(error)")
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
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil), cachePolicy: .networkOnly)
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []

            // Find new posts that aren't in the current list
            let existingIds = Set(posts.map { $0.id })
            let newPosts = fetchedPosts.filter { !existingIds.contains($0.id) }

            if !newPosts.isEmpty {
                // Check if there's a gap (fetched posts don't include our first post)
                if let firstCurrentPost = posts.first,
                   !fetchedPosts.contains(where: { $0.id == firstCurrentPost.id }) {
                    hasGap = true
                    newPostsCount = newPosts.count
                } else {
                    hasGap = false
                    newPostsCount = 0
                }

                // Prepend new posts
                posts = newPosts + posts
            } else {
                hasGap = false
                newPostsCount = 0
            }
        } catch {
            print("Error refreshing posts: \(error)")
        }
    }

    private func loadGap() async {
        hasGap = false
        newPostsCount = 0
        isLoading = true
        defer { isLoading = false }

        do {
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil))
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {
            print("Error loading gap: \(error)")
        }
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
    }

    private func fetchProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.ActorByHandleQuery(handle: handle, after: nil))
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

