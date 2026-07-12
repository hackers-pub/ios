import Kingfisher
import SwiftUI

enum SearchResultType: Identifiable, Hashable {
    case post(HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node)
    case actor(SearchActor)
    case resolvedPost(id: String, url: String)

    var id: String {
        switch self {
        case let .post(post): return "post-\(post.id)"
        case let .actor(actor): return "actor-\(actor.id)"
        case let .resolvedPost(id, _): return "resolved-post-\(id)"
        }
    }
}

extension SearchResultType {
    var postContentListIdentity: PostListItemIdentity? {
        switch self {
        case let .post(post):
            postListItemIdentity(rowID: id, post: post)
        case let .resolvedPost(id, _):
            PostListItemIdentity(
                rowID: self.id,
                postID: id,
                displayedPostID: nil
            )
        case .actor:
            nil
        }
    }
}

typealias SearchRouterRequestAcknowledgement = @MainActor (SearchRequest) -> Void

struct SearchView: View {
    @Binding var searchText: String
    @Binding var showingComposeView: Bool
    let searchSubmitRequest: SearchSubmitRequest?
    let routerSearchRequest: SearchRequest?
    let onRouterSearchRequestHandled: SearchRouterRequestAcknowledgement
    @State private var searchSession: SearchSession
    @State private var postContentGeneration = 0
    @State private var recentSearchStore: SearchRecentStore
    @State private var routerRequestCoordinator = SearchRouterRequestCoordinator()
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager

    private var recentSearches: [String] {
        recentSearchStore.searches
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .search)) {
            Group {
                if searchText.isEmpty {
                    if !recentSearches.isEmpty {
                        List {
                            Section {
                                ForEach(recentSearches, id: \.self) { query in
                                    Button {
                                        searchText = query
                                        searchSession.selectRecent(query)
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundStyle(.secondary)
                                            Text(query)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .accessibilityIdentifier("search.recent.\(query)")
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            recentSearchStore.delete(query)
                                        } label: {
                                            Label(
                                                NSLocalizedString(
                                                    "search.recent.delete",
                                                    comment: "Delete recent search"
                                                ),
                                                systemImage: "trash"
                                            )
                                        }
                                        .accessibilityIdentifier("search.recent.delete.\(query)")
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(NSLocalizedString("search.recentSearches", comment: "Recent searches section"))
                                    Spacer()
                                    Button(NSLocalizedString("search.recent.clear", comment: "Clear recent searches")) {
                                        recentSearchStore.clear()
                                    }
                                    .accessibilityIdentifier("search.recent.clear")
                                    .textCase(nil)
                                }
                            }
                        }
                        .listStyle(.plain)
                    } else {
                        ContentUnavailableView(
                            NSLocalizedString("nav.search", comment: "Search navigation title"),
                            systemImage: "magnifyingglass",
                            description: Text(
                                NSLocalizedString("search.initial.description", comment: "Initial search description")
                            )
                        )
                        .accessibilityIdentifier("search.initial")
                    }
                } else if let errorMessage = searchSession.failureMessage, searchSession.results.isEmpty {
                    LoadFailureView(message: errorMessage) {
                        searchSession.retry()
                    }
                } else if !isLoading && directActors.isEmpty && relatedActors.isEmpty && posts.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("search.noResults.title", comment: "No search results title"),
                        systemImage: "magnifyingglass",
                        description: Text(
                            NSLocalizedString("search.noResults.description", comment: "No search results description")
                        )
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if let errorMessage = searchSession.errorMessage {
                                InlineLoadFailureView(message: errorMessage) {
                                    searchSession.retry()
                                }
                            }

                            if showsDirectActorSection {
                                sectionHeader(NSLocalizedString("search.accounts", comment: "Accounts section"))

                                ForEach(directActors, id: \.id) { result in
                                    if case let .actor(actor) = result {
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

                                if let errorMessage = searchSession.failureMessage(for: .accounts) {
                                    InlineLoadFailureView(message: errorMessage) {
                                        searchSession.retry()
                                    }
                                }
                            }

                            if showsRelatedActorSection {
                                sectionHeader(
                                    NSLocalizedString("search.relatedAccounts", comment: "Related accounts section")
                                )

                                ForEach(relatedActors, id: \.id) { result in
                                    if case let .actor(actor) = result {
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

                                if let errorMessage = searchSession.failureMessage(for: .relatedAccounts) {
                                    InlineLoadFailureView(message: errorMessage) {
                                        searchSession.retry()
                                    }
                                }
                            }

                            if !posts.isEmpty || isLoadingPosts || searchSession.failureMessage(for: .posts) != nil {
                                sectionHeader(NSLocalizedString("search.posts", comment: "Posts section"))

                                ForEach(posts, id: \.id) { result in
                                    switch result {
                                    case let .post(post):
                                        if post.isArticle {
                                            SearchResultRow(result: result)
                                                .padding()
                                        } else {
                                            NavigationLink(value: NavigationDestination.post(id: post.id)) {
                                                SearchResultRow(result: result)
                                                    .padding()
                                            }
                                        }
                                    case let .resolvedPost(id, _):
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

                                if let errorMessage = searchSession.failureMessage(for: .posts) {
                                    InlineLoadFailureView(message: errorMessage) {
                                        searchSession.retry()
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
                case let .profile(handle):
                    ActorProfileViewWrapper(handle: handle)
                case let .post(id):
                    PostDetailView(postId: id)
                case let .newsStory(id):
                    NewsStoryDetailView(storyId: id)
                }
            }
            .toolbar {
                if authManager.isAuthenticated {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingComposeView = true
                        } label: {
                            Label(
                                NSLocalizedString("common.newPost", comment: "New post button"),
                                systemImage: "square.and.pencil"
                            )
                        }
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                postContentGeneration += 1
                handleSearchTextChange(newValue)
            }
            .onChange(of: searchSubmitRequest) { _, submitRequest in
                guard let submitRequest else { return }
                searchSession.submit(submitRequest.query)
            }
            .task(id: routerSearchRequest?.id) {
                handleRouterSearchRequest(routerSearchRequest)
            }
            .onAppear {
                searchSession.viewDidAppear(query: searchText)
            }
            .onDisappear {
                searchSession.viewDidDisappear()
            }
            .onReceive(NotificationCenter.default.publisher(for: .postContentDidChange)) { notification in
                handlePostContentNotification(notification)
            }
        }
        .accessibilityIdentifier("search.screen")
    }

    @MainActor
    private func handlePostContentNotification(_ notification: Notification) {
        guard let event = PostContentEventCenter.event(from: notification) else { return }
        let action = PostContentListEventRouter.route(
            event,
            host: .search,
            rows: posts.compactMap(\.postContentListIdentity),
            eventGeneration: postContentGeneration,
            activeGeneration: postContentGeneration
        )
        guard case let .remove(rowIDs) = action else { return }
        postContentGeneration += 1
        searchSession.removePosts(withRowIDs: rowIDs)
    }
}

extension SearchView {
    init(
        searchText: Binding<String>,
        showingComposeView: Binding<Bool> = .constant(false),
        searchSubmitRequest: SearchSubmitRequest? = nil,
        routerSearchRequest: SearchRequest? = nil,
        onRouterSearchRequestHandled: @escaping SearchRouterRequestAcknowledgement = { _ in }
    ) {
        _searchText = searchText
        _showingComposeView = showingComposeView
        self.searchSubmitRequest = searchSubmitRequest
        self.routerSearchRequest = routerSearchRequest
        self.onRouterSearchRequestHandled = onRouterSearchRequestHandled
        let recentSearchStore = SearchRecentStore()
        _recentSearchStore = State(initialValue: recentSearchStore)
        _searchSession = State(initialValue: SearchSession(
            request: SearchView.executeSearch,
            onSuccessfulExplicitSearch: { query in
                recentSearchStore.record(query)
            }
        ))
    }
}

private extension SearchView {
    var isLoading: Bool {
        searchSession.isLoading
    }

    var directActors: [SearchResultType] {
        searchSession.directActors
    }

    var relatedActors: [SearchResultType] {
        searchSession.relatedActors
    }

    var posts: [SearchResultType] {
        searchSession.posts
    }

    var isLoadingPosts: Bool {
        searchSession.isLoading
    }

    var isLoadingDirectActors: Bool {
        searchSession.isLoading
    }

    var isLoadingRelatedActors: Bool {
        searchSession.isLoading
    }

    var showsDirectActorSection: Bool {
        !directActors.isEmpty || isLoadingDirectActors ||
            searchSession.failureMessage(for: .accounts) != nil
    }

    var showsRelatedActorSection: Bool {
        !relatedActors.isEmpty || isLoadingRelatedActors ||
            searchSession.failureMessage(for: .relatedAccounts) != nil
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    func handleSearchTextChange(_ newValue: String) {
        routerRequestCoordinator.handleAutomaticInput(
            newValue,
            currentQuery: searchText,
            submit: searchSession.inputChanged
        )
    }

    func handleRouterSearchRequest(_ request: SearchRequest?) {
        guard routerRequestCoordinator.handle(
            request,
            currentQuery: searchText,
            applyQuery: { searchText = $0 },
            submit: searchSession.submit
        ), let request else {
            return
        }
        onRouterSearchRequestHandled(request)
    }

    @MainActor
    static func executeSearch(query: String) async throws -> SearchResults {
        try await SearchService().search(query: query)
    }
}

struct SearchResultRow: View {
    let result: SearchResultType
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        switch result {
        case let .post(post):
            PostView(post: post, contentRenderMode: .lightweightText)

        case let .resolvedPost(id, url):
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
            .accessibilityIdentifier("search.result.resolved.\(id)")

        case let .actor(actor):
            HStack(spacing: 12) {
                Button {
                    navigationCoordinator.navigateToProfile(handle: actor.handle)
                } label: {
                    KFImage(URL(string: actor.avatarURL))
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
