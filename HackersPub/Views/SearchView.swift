import SwiftUI
import Kingfisher
@preconcurrency import Apollo

enum SearchResultType: Identifiable, Hashable {
    case post(HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node)
    case actor(HackersPub.ActorByHandleQuery.Data.ActorByHandle)
    case resolvedPost(id: String, url: String)

    var id: String {
        switch self {
        case .post(let post): return "post-\(post.id)"
        case .actor(let actor): return "actor-\(actor.id)"
        case .resolvedPost(let id, _): return "resolved-post-\(id)"
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
    @Environment(AuthManager.self) private var authManager

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
        NavigationStack(path: navigationCoordinator.pathBinding(for: .search)) {
            Group {
                if searchText.isEmpty {
                    if !recentSearches.isEmpty {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                sectionHeader(NSLocalizedString("search.recentSearches", comment: "Recent searches section"))

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
                                        .padding()
                                    }
                                    Divider()
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
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if !directActors.isEmpty || isLoadingDirectActors {
                                sectionHeader(NSLocalizedString("search.accounts", comment: "Accounts section"))

                                ForEach(directActors, id: \.id) { result in
                                    if case .actor(let actor) = result {
                                        NavigationLink(value: NavigationDestination.profile(handle: actor.handle)) {
                                            SearchResultRow(result: result)
                                                .padding()
                                        }
                                    }
                                    Divider()
                                }

                                if isLoadingDirectActors {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }

                            if !relatedActors.isEmpty || isLoadingRelatedActors {
                                sectionHeader(NSLocalizedString("search.relatedAccounts", comment: "Related accounts section"))

                                ForEach(relatedActors, id: \.id) { result in
                                    if case .actor(let actor) = result {
                                        NavigationLink(value: NavigationDestination.profile(handle: actor.handle)) {
                                            SearchResultRow(result: result)
                                                .padding()
                                        }
                                    }
                                    Divider()
                                }

                                if isLoadingRelatedActors {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }

                            if !posts.isEmpty || isLoadingPosts {
                                sectionHeader(NSLocalizedString("search.posts", comment: "Posts section"))

                                ForEach(posts, id: \.id) { result in
                                    switch result {
                                    case .post(let post):
                                        if post.isArticle {
                                            SearchResultRow(result: result)
                                                .padding()
                                        } else {
                                            NavigationLink(value: NavigationDestination.post(id: post.id)) {
                                                SearchResultRow(result: result)
                                                    .padding()
                                            }
                                        }
                                    case .resolvedPost(let id, _):
                                        NavigationLink(value: NavigationDestination.post(id: id)) {
                                            SearchResultRow(result: result)
                                                .padding()
                                        }
                                    case .actor:
                                        EmptyView()
                                    }
                                    Divider()
                                }

                                if isLoadingPosts {
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

                        guard !Task.isCancelled else { return }
                        await performSearch(query: newValue)
                        guard !Task.isCancelled else { return }
                        addToRecentSearches(newValue)
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
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

        let seenActors = ActorTracker()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await searchAndDisplayPosts(query: query, seenActors: seenActors)
            }
            group.addTask {
                await searchAndDisplayDirectActor(query: query, seenActors: seenActors)
            }
            group.addTask {
                await searchAndDisplayObject(query: query, seenActors: seenActors)
            }
        }
    }

    private func searchAndDisplayPosts(query: String, seenActors: ActorTracker) async {
        let postResults = await searchPosts(query: query)
        guard !Task.isCancelled else { return }

        await MainActor.run {
            self.posts = postResults.map { .post($0) }
            self.isLoadingPosts = false
        }

        // Extract unique actors from posts
        var actorResults: [SearchResultType] = []
        for post in postResults {
            guard !Task.isCancelled else { return }
            if await seenActors.insert(post.actor.id) {
                if let actorResult = await searchActor(handle: post.actor.handle) {
                    actorResults.append(.actor(actorResult))
                }
            }
        }

        // Update related actors from posts
        if !actorResults.isEmpty {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.relatedActors.append(contentsOf: actorResults)
            }
        }

        // Turn off related actor loading after extracting from posts
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.isLoadingRelatedActors = false
        }
    }

    private func searchAndDisplayDirectActor(query: String, seenActors: ActorTracker) async {
        if let directActor = await searchActorByHandle(query: query) {
            guard !Task.isCancelled else { return }
            if await seenActors.insert(directActor.id) {
                await MainActor.run {
                    self.directActors.append(.actor(directActor))
                }
            }
        }

        // Turn off direct actor loading after direct search completes
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.isLoadingDirectActors = false
        }
    }

    private func searchAndDisplayObject(query: String, seenActors: ActorTracker) async {
        guard !Task.isCancelled else { return }
        if let objectUrl = await searchObject(query: query) {
            guard !Task.isCancelled else { return }
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
        if let resolvedURL = URL(string: url),
           case .profile(let handle) = HackersPubURLRouter.resolve(resolvedURL),
           let actor = await searchActor(handle: handle),
           await seenActors.insert(actor.id) {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.directActors.append(.actor(actor))
            }
            return
        }

        do {
            guard let postID = try await DeepLinkPostResolver.resolvePostID(for: url) else { return }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if !self.posts.contains(where: { $0.id == "resolved-post-\(postID)" || $0.id == "post-\(postID)" }) {
                    self.posts.append(.resolvedPost(id: postID, url: url))
                }
            }
        } catch {
            print("Error resolving searched object URL: \(error)")
        }
    }

    private func searchActor(handle: String) async -> HackersPub.ActorByHandleQuery.Data.ActorByHandle? {
        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorByHandleQuery(handle: handle, after: nil, before: nil, first: 20, last: nil)
            )
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
            PostView(post: post, contentRenderMode: .lightweightText)

        case .resolvedPost(_, let url):
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("search.resolvedPost", comment: "Resolved search post result title"))
                        .font(.headline)
                    Text(url)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

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
                PostView(post: post, contentRenderMode: .lightweightText)
                    .padding()
            }

        case .resolvedPost(let id, _):
            PostDetailView(postId: id)

        case .actor(let actor):
            ActorProfileView(actor: actor)
        }
    }
}
