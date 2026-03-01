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
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: Bindable(navigationCoordinator).path) {
            Group {
                switch selectedScope {
                case .local:
                    LocalTimelineContent(showingComposeView: $showingComposeView)
                case .global:
                    GlobalTimelineContent(showingComposeView: $showingComposeView)
                }
            }
            .navigationTitle(NSLocalizedString("nav.explore", comment: "Explore navigation title"))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker(NSLocalizedString("explore.scope", comment: "Scope picker"), selection: $selectedScope) {
                        ForEach(ExploreScope.allCases, id: \.self) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }
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
    @State private var posts: [LocalPost] = []
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var shouldRefresh = false
    @State private var showingSettings = false
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if isLoading && posts.isEmpty {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(posts, id: \.id) { post in
                            PostView(post: post)
                                .padding()
                                .onAppear {
                                    if post.id == posts.last?.id && hasNextPage && !isLoading {
                                        Task {
                                            await loadMore()
                                        }
                                    }
                                }

                            Divider()
                        }

                        if isLoading && !posts.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                        }
                    }
                }
            }
        }
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
    }

    private func fetchPosts() async {
        print("🟠 LocalTimelineContent: Starting to fetch posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            print("🟠 LocalTimelineContent: Calling apolloClient.fetch...")
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil))
            print("🟠 LocalTimelineContent: Got response, data exists: \(response.data != nil)")

            if let errors = response.errors, !errors.isEmpty {
                print("⚠️ LocalTimelineContent: GraphQL errors present:")
                for error in errors {
                    print("   - \(error.message ?? "Unknown error")")
                    if let extensions = error["extensions"] as? [String: Any] {
                        print("   Extensions: \(extensions)")
                    }
                }
            }

            print("🟠 LocalTimelineContent: Edges count: \(response.data?.publicTimeline.edges.count ?? 0)")

            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            print("🟠 LocalTimelineContent: Mapped posts count: \(fetchedPosts.count)")

            if let firstPost = fetchedPosts.first {
                print("🟠 LocalTimelineContent: First post ID: \(firstPost.id)")
                print("🟠 LocalTimelineContent: First post content length: \(firstPost.content.count)")
            }

            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            print("🟠 LocalTimelineContent: Set posts array, count: \(posts.count)")
        } catch {
            print("❌ LocalTimelineContent: Error fetching posts: \(error)")
            print("❌ LocalTimelineContent: Error details: \(String(describing: error))")
            print("❌ LocalTimelineContent: Error type: \(type(of: error))")
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
        print("🟠 LocalTimelineContent: Refreshing posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil), cachePolicy: .networkOnly)
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {
            print("❌ LocalTimelineContent: Error refreshing posts: \(error)")
        }
    }
}

// Extracted GlobalTimeline content without NavigationStack
struct GlobalTimelineContent: View {
    @Binding var showingComposeView: Bool
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var shouldRefresh = false
    @State private var showingSettings = false
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if isLoading && posts.isEmpty {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(posts, id: \.id) { post in
                            PostView(post: post)
                                .padding()
                                .onAppear {
                                    if post.id == posts.last?.id && hasNextPage && !isLoading {
                                        Task {
                                            await loadMore()
                                        }
                                    }
                                }

                            Divider()
                        }

                        if isLoading && !posts.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                        }
                    }
                }
            }
        }
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
    }

    private func fetchPosts() async {
        print("🔵 GlobalTimelineContent: Starting to fetch posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            print("🔵 GlobalTimelineContent: Calling apolloClient.fetch...")
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil))
            print("🔵 GlobalTimelineContent: Got response, data exists: \(response.data != nil)")

            if let errors = response.errors, !errors.isEmpty {
                print("⚠️ GlobalTimelineContent: GraphQL errors present:")
                for error in errors {
                    print("   - \(error.message ?? "Unknown error")")
                    if let extensions = error["extensions"] as? [String: Any] {
                        print("   Extensions: \(extensions)")
                    }
                }
            }

            print("🔵 GlobalTimelineContent: Edges count: \(response.data?.publicTimeline.edges.count ?? 0)")

            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            print("🔵 GlobalTimelineContent: Mapped posts count: \(fetchedPosts.count)")

            if let firstPost = fetchedPosts.first {
                print("🔵 GlobalTimelineContent: First post ID: \(firstPost.id)")
                print("🔵 GlobalTimelineContent: First post name: \(firstPost.name ?? "nil")")
                print("🔵 GlobalTimelineContent: First post summary: \(firstPost.summary ?? "nil")")
                print("🔵 GlobalTimelineContent: First post content length: \(firstPost.content.count)")
            }

            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
            print("🔵 GlobalTimelineContent: Set posts array, count: \(posts.count)")
        } catch {
            print("❌ GlobalTimelineContent: Error fetching posts: \(error)")
            print("❌ GlobalTimelineContent: Error details: \(String(describing: error))")
            print("❌ GlobalTimelineContent: Error type: \(type(of: error))")
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
        print("🔵 GlobalTimelineContent: Refreshing posts...")
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil), cachePolicy: .networkOnly)
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {
            print("❌ GlobalTimelineContent: Error refreshing posts: \(error)")
        }
    }
}
