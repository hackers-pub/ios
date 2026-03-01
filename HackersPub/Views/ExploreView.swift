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
    @State private var hasLoadedInitial = false
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
                            PostView(post: post, enableSneakPeek: true)
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
    }

    private func fetchPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil))
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []

            posts = fetchedPosts
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
            let newPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts.append(contentsOf: newPosts)
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }

    private func refreshPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil), cachePolicy: .networkOnly)
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }
}

// Extracted GlobalTimeline content without NavigationStack
struct GlobalTimelineContent: View {
    @Binding var showingComposeView: Bool
    @State private var posts: [Post] = []
    @State private var hasLoadedInitial = false
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
                            PostView(post: post, enableSneakPeek: true)
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
    }

    private func fetchPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil))
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []

            posts = fetchedPosts
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
            let newPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts.append(contentsOf: newPosts)
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }

    private func refreshPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil), cachePolicy: .networkOnly)
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {}
    }
}
