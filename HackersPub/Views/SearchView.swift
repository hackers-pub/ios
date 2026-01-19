import SwiftUI
import Kingfisher
@preconcurrency import Apollo

enum SearchResultType: Identifiable, Hashable {
    case post(HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node)
    case actor(HackersPub.ActorByHandleQuery.Data.ActorByHandle)

    var id: String {
        switch self {
        case .post(let post): return "post-\(post.id)"
        case .actor(let actor): return "actor-\(actor.id)"
        }
    }
}

actor ActorTracker {
    private var seenActors = Set<String>()

    func insert(_ id: String) -> Bool {
        if seenActors.contains(id) {
            return false
        }
        seenActors.insert(id)
        return true
    }
}

struct SearchView: View {
    @Binding var searchText: String
    @Binding var showingComposeView: Bool
    @State private var directActors: [SearchResultType] = []
    @State private var relatedActors: [SearchResultType] = []
    @State private var posts: [SearchResultType] = []
    @State private var isLoadingPosts = false
    @State private var isLoadingDirectActors = false
    @State private var isLoadingRelatedActors = false
    @State private var searchTask: Task<Void, Never>?
    @AppStorage("recentSearches") private var recentSearchesData: Data = Data()
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    private var isLoading: Bool {
        isLoadingPosts || isLoadingDirectActors || isLoadingRelatedActors
    }

    init(searchText: Binding<String>, showingComposeView: Binding<Bool> = .constant(false)) {
        self._searchText = searchText
        self._showingComposeView = showingComposeView
    }

    private var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? []
    }

    var body: some View {
        NavigationStack(path: Bindable(navigationCoordinator).path) {
            Group {
                if searchText.isEmpty {
                    if !recentSearches.isEmpty {
                        List {
                            Section(NSLocalizedString("search.recentSearches", comment: "Recent searches section")) {
                                ForEach(recentSearches, id: \.self) { query in
                                    Button {
                                        searchText = query
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundStyle(.secondary)
                                            Text(query)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                    }
                                }
                                .onDelete { indexSet in
                                    var searches = recentSearches
                                    searches.remove(atOffsets: indexSet)
                                    saveRecentSearches(searches)
                                }
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            NSLocalizedString("nav.search", comment: "Search navigation title"),
                            systemImage: "magnifyingglass",
                            description: Text(NSLocalizedString("search.noResults.description", comment: "No search results description"))
                        )
                    }
                } else if !isLoading && directActors.isEmpty && relatedActors.isEmpty && posts.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("search.noResults.title", comment: "No search results title"),
                        systemImage: "magnifyingglass",
                        description: Text(NSLocalizedString("search.noResults.description", comment: "No search results description"))
                    )
                } else {
                    List {
                        if !directActors.isEmpty || isLoadingDirectActors {
                            Section(NSLocalizedString("search.accounts", comment: "Accounts section")) {
                                ForEach(directActors, id: \.id) { result in
                                    if case .actor(let actor) = result {
                                        NavigationLink(value: NavigationDestination.profile(handle: actor.handle)) {
                                            SearchResultRow(result: result)
                                        }
                                    }
                                }

                                if isLoadingDirectActors {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                }
                            }
                        }

                        if !relatedActors.isEmpty || isLoadingRelatedActors {
                            Section(NSLocalizedString("search.relatedAccounts", comment: "Related accounts section")) {
                                ForEach(relatedActors, id: \.id) { result in
                                    if case .actor(let actor) = result {
                                        NavigationLink(value: NavigationDestination.profile(handle: actor.handle)) {
                                            SearchResultRow(result: result)
                                        }
                                    }
                                }

                                if isLoadingRelatedActors {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                }
                            }
                        }

                        if !posts.isEmpty || isLoadingPosts {
                            Section(NSLocalizedString("search.posts", comment: "Posts section")) {
                                ForEach(posts, id: \.id) { result in
                                    if case .post(let post) = result {
                                        NavigationLink(value: NavigationDestination.post(id: post.id)) {
                                            SearchResultRow(result: result)
                                        }
                                    }
                                }

                                if isLoadingPosts {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav.search", comment: "Search navigation title"))
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .profile(let handle):
                    ActorProfileViewWrapper(handle: handle)
                case .post(let id):
                    PostDetailView(postId: id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingComposeView = true
                    } label: {
                        Label(NSLocalizedString("common.newPost", comment: "New post button"), systemImage: "square.and.pencil")
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                // Cancel previous search task
                searchTask?.cancel()

                if !newValue.isEmpty {
                    // Set loading state immediately
                    isLoadingPosts = true
                    isLoadingDirectActors = true
                    isLoadingRelatedActors = true

                    // Debounce: wait 500ms before searching
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(500))

                        if !Task.isCancelled {
                            await performSearch(query: newValue)
                            addToRecentSearches(newValue)
                        } else {
                            // If cancelled, reset loading states
                            isLoadingPosts = false
                            isLoadingDirectActors = false
                            isLoadingRelatedActors = false
                        }
                    }
                } else {
                    directActors = []
                    relatedActors = []
                    posts = []
                    isLoadingPosts = false
                    isLoadingDirectActors = false
                    isLoadingRelatedActors = false
                }
            }
        }
    }

    private func saveRecentSearches(_ searches: [String]) {
        if let encoded = try? JSONEncoder().encode(searches) {
            recentSearchesData = encoded
        }
    }

    private func addToRecentSearches(_ query: String) {
        var searches = recentSearches
        // Remove if already exists
        searches.removeAll { $0 == query }
        // Add to beginning
        searches.insert(query, at: 0)
        // Keep only 10 most recent
        if searches.count > 10 {
            searches = Array(searches.prefix(10))
        }
        saveRecentSearches(searches)
    }

    private func performSearch(query: String) async {
        await MainActor.run {
            // Clear previous results and start loading
            directActors = []
            relatedActors = []
            posts = []
            isLoadingPosts = true
            isLoadingDirectActors = true
            isLoadingRelatedActors = true
        }

        // Track seen actors across all tasks
        let seenActors = ActorTracker()

        // Launch all searches concurrently without waiting
        Task {
            await searchAndDisplayPosts(query: query, seenActors: seenActors)
        }

        Task {
            await searchAndDisplayDirectActor(query: query, seenActors: seenActors)
        }

        Task {
            await searchAndDisplayObject(query: query, seenActors: seenActors)
        }
    }

    private func searchAndDisplayPosts(query: String, seenActors: ActorTracker) async {
        let postResults = await searchPosts(query: query)
        await MainActor.run {
            self.posts = postResults.map { .post($0) }
            self.isLoadingPosts = false
        }

        // Extract unique actors from posts
        var actorResults: [SearchResultType] = []
        for post in postResults {
            if await seenActors.insert(post.actor.id) {
                if let actorResult = await searchActor(handle: post.actor.handle) {
                    actorResults.append(.actor(actorResult))
                }
            }
        }

        // Update related actors from posts
        if !actorResults.isEmpty {
            await MainActor.run {
                self.relatedActors.append(contentsOf: actorResults)
            }
        }

        // Turn off related actor loading after extracting from posts
        await MainActor.run {
            self.isLoadingRelatedActors = false
        }
    }

    private func searchAndDisplayDirectActor(query: String, seenActors: ActorTracker) async {
        if let directActor = await searchActorByHandle(query: query) {
            if await seenActors.insert(directActor.id) {
                await MainActor.run {
                    self.directActors.append(.actor(directActor))
                }
            }
        }

        // Turn off direct actor loading after direct search completes
        await MainActor.run {
            self.isLoadingDirectActors = false
        }
    }

    private func searchAndDisplayObject(query: String, seenActors: ActorTracker) async {
        if let objectUrl = await searchObject(query: query) {
            await handleSearchedObjectUrl(objectUrl, seenActors: seenActors)
        }
    }

    private func searchPosts(query: String) async -> [HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node] {
        do {
            let response = try await apolloClient.fetch(query: HackersPub.SearchPostQuery(query: query))
            return response.data?.searchPost.edges.map { $0.node } ?? []
        } catch {
            print("Error searching posts: \(error)")
            return []
        }
    }

    private func searchObject(query: String) async -> String? {
        do {
            let response = try await apolloClient.fetch(query: HackersPub.SearchObjectQuery(query: query))
            if let data = response.data?.searchObject {
                if let searchedObject = data.asSearchedObject {
                    return searchedObject.url
                }
            }
            return nil
        } catch {
            print("Error searching object: \(error)")
            return nil
        }
    }

    private func searchActorByHandle(query: String) async -> HackersPub.ActorByHandleQuery.Data.ActorByHandle? {
        // Try searching with the query as-is (might be a handle)
        return await searchActor(handle: query)
    }

    private func handleSearchedObjectUrl(_ url: String, seenActors: ActorTracker) async {
        // This is a placeholder for handling fetched URLs
        // The URL could point to an actor profile or a post
        // You could parse the URL and extract relevant information
        print("Found object URL: \(url)")
    }

    private func searchActor(handle: String) async -> HackersPub.ActorByHandleQuery.Data.ActorByHandle? {
        do {
            let response = try await apolloClient.fetch(query: HackersPub.ActorByHandleQuery(handle: handle, after: nil))
            return response.data?.actorByHandle
        } catch {
            return nil
        }
    }

}

struct SearchResultRow: View {
    let result: SearchResultType
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        switch result {
        case .post(let post):
            PostView(post: post)

        case .actor(let actor):
            HStack(spacing: 12) {
                Button {
                    navigationCoordinator.navigateToProfile(handle: actor.handle)
                } label: {
                    KFImage(URL(string: actor.avatarUrl))
                        .placeholder {
                            Color.gray.opacity(0.2)
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    navigationCoordinator.navigateToProfile(handle: actor.handle)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let name = actor.name {
                            HTMLTextView(html: name, font: .headline)
                        }
                        Text(actor.handle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SearchDetailView: View {
    let result: SearchResultType

    var body: some View {
        switch result {
        case .post(let post):
            ScrollView {
                PostView(post: post)
                    .padding()
            }

        case .actor(let actor):
            ActorProfileView(actor: actor)
        }
    }
}

struct ActorProfileView: View {
    let actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle
    @State private var posts: [HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node] = []
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    KFImage(URL(string: actor.avatarUrl))
                        .placeholder {
                            Color.gray.opacity(0.2)
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())

                    VStack(spacing: 8) {
                        if let name = actor.name {
                            HTMLTextView(html: name, font: .title)
                        }
                        Text(actor.handle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let bio = actor.bio {
                        HTMLContentView(html: bio, media: [])
                            .padding(.horizontal)
                    }
                }
                .padding()

                Divider()

                if !posts.isEmpty {
                    LazyVStack(spacing: 0) {
                        ForEach(posts, id: \.id) { post in
                            NavigationLink(value: NavigationDestination.post(id: post.id)) {
                                PostView(post: post, showAuthor: true, disableNavigation: true)
                                    .padding()
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if post.id == posts.last?.id && hasNextPage && !isLoading {
                                    Task {
                                        await loadMore()
                                    }
                                }
                            }
                            Divider()
                        }

                        if isLoading {
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
    }

    private func fetchPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.ActorByHandleQuery(handle: actor.handle, after: nil))
            if let actorData = response.data?.actorByHandle {
                posts = actorData.posts.edges.map { $0.node }
                hasNextPage = actorData.posts.pageInfo.hasNextPage
                endCursor = actorData.posts.pageInfo.endCursor
            }
        } catch {
            print("Error fetching actor posts: \(error)")
        }
    }

    private func refreshPosts() async {
        do {
            // Fetch from network, ignoring cache
            let response = try await apolloClient.fetch(query: HackersPub.ActorByHandleQuery(handle: actor.handle, after: nil), cachePolicy: .networkOnly)
            if let actorData = response.data?.actorByHandle {
                posts = actorData.posts.edges.map { $0.node }
                hasNextPage = actorData.posts.pageInfo.hasNextPage
                endCursor = actorData.posts.pageInfo.endCursor
            }
        } catch {
            print("Error refreshing actor posts: \(error)")
        }
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.ActorByHandleQuery(handle: actor.handle, after: .some(cursor)))
            if let actorData = response.data?.actorByHandle {
                let newPosts = actorData.posts.edges.map { $0.node }
                posts.append(contentsOf: newPosts)
                hasNextPage = actorData.posts.pageInfo.hasNextPage
                endCursor = actorData.posts.pageInfo.endCursor
            }
        } catch {
            print("Error loading more actor posts: \(error)")
        }
    }
}
