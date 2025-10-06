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

struct SearchView: View {
    @Binding var searchText: String
    @Binding var showingComposeView: Bool
    @State private var actors: [SearchResultType] = []
    @State private var posts: [SearchResultType] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?
    @AppStorage("recentSearches") private var recentSearchesData: Data = Data()
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

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
                if isLoading {
                    ProgressView()
                } else if actors.isEmpty && posts.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("search.noResults.title", comment: "No search results title"),
                        systemImage: "magnifyingglass",
                        description: Text(NSLocalizedString("search.noResults.description", comment: "No search results description"))
                    )
                } else if searchText.isEmpty && !recentSearches.isEmpty {
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
                    List {
                        if !actors.isEmpty {
                            Section(NSLocalizedString("search.accounts", comment: "Accounts section")) {
                                ForEach(actors, id: \.id) { result in
                                    NavigationLink(value: result) {
                                        SearchResultRow(result: result)
                                    }
                                }
                            }
                        }

                        if !posts.isEmpty {
                            Section(NSLocalizedString("search.posts", comment: "Posts section")) {
                                ForEach(posts, id: \.id) { result in
                                    NavigationLink(value: result) {
                                        SearchResultRow(result: result)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav.search", comment: "Search navigation title"))
            .navigationDestination(for: SearchResultType.self) { result in
                SearchDetailView(result: result)
            }
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
                    // Debounce: wait 500ms before searching
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(500))

                        if !Task.isCancelled {
                            await performSearch(query: newValue)
                            addToRecentSearches(newValue)
                        }
                    }
                } else {
                    actors = []
                    posts = []
                    isLoading = false
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
        isLoading = true
        defer { isLoading = false }

        var actorResults: [SearchResultType] = []
        var postResults: [SearchResultType] = []
        var seenActors = Set<String>()

        // Search posts (which includes actor information)
        do {
            let response = try await apolloClient.fetch(query: HackersPub.SearchPostQuery(query: query))
            let posts = response.data?.searchPost.edges.map { $0.node } ?? []

            // Extract unique actors from posts
            for post in posts {
                if !seenActors.contains(post.actor.id) {
                    seenActors.insert(post.actor.id)
                    // Create an actor result using actorByHandle to get full profile
                    if let actorResult = await searchActor(handle: post.actor.handle) {
                        actorResults.append(.actor(actorResult))
                    }
                }
            }

            postResults = posts.map { .post($0) }
        } catch {
            print("Error searching posts: \(error)")
        }

        actors = actorResults
        self.posts = postResults
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
