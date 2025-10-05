import SwiftUI
@preconcurrency import Apollo

enum ExploreScope: String, CaseIterable {
    case local = "Hackers' Pub"
    case global = "Fediverse"
}

struct ExploreView: View {
    @Binding var showingComposeView: Bool
    @State private var selectedScope: ExploreScope = .local

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        self._showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedScope {
                case .local:
                    LocalTimelineContent(showingComposeView: $showingComposeView)
                case .global:
                    GlobalTimelineContent(showingComposeView: $showingComposeView)
                }
            }
            .navigationTitle("Explore")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Scope", selection: $selectedScope) {
                        ForEach(ExploreScope.allCases, id: \.self) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
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

    var body: some View {
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
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.LocalTimelineQuery(after: nil))
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

    var body: some View {
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
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.PublicTimelineQuery(after: nil))
            let fetchedPosts = response.data?.publicTimeline.edges.map { $0.node } ?? []
            posts = fetchedPosts
            hasNextPage = response.data?.publicTimeline.pageInfo.hasNextPage ?? false
            endCursor = response.data?.publicTimeline.pageInfo.endCursor
        } catch {
            print("❌ GlobalTimelineContent: Error refreshing posts: \(error)")
        }
    }
}
