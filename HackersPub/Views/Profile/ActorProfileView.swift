import Kingfisher
import SwiftUI
@preconcurrency import Apollo

private struct ActorRelationshipTagsView: View {
    let followsViewer: Bool
    let viewerBlocks: Bool

    var body: some View {
        HStack(spacing: 8) {
            if followsViewer {
                Text(NSLocalizedString("profile.tag.followsViewer", comment: "Follows viewer tag"))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }

            if viewerBlocks {
                Text(NSLocalizedString("profile.tag.viewerBlocks", comment: "Viewer blocks actor tag"))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct ActorProfileActionMenu: View {
    let state: ActorRelationshipState
    let isPerformingAction: Bool
    let onAction: (ActorRelationshipAction) -> Void

    var body: some View {
        Menu {
            if state.followsViewer {
                Button {
                    onAction(.removeFollower)
                } label: {
                    Label(NSLocalizedString("profile.action.removeFollower", comment: "Remove follower"), systemImage: "person.crop.circle.badge.minus")
                }
                .disabled(isPerformingAction)
            }

            Button(role: state.viewerBlocks ? nil : .destructive) {
                onAction(state.viewerBlocks ? .unblock : .block)
            } label: {
                Label(
                    state.viewerBlocks
                        ? NSLocalizedString("profile.action.unblock", comment: "Unblock actor")
                        : NSLocalizedString("profile.action.block", comment: "Block actor"),
                    systemImage: state.viewerBlocks ? "nosign" : "hand.raised"
                )
            }
            .disabled(isPerformingAction)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

private struct EditableProfileAccount: Identifiable {
    let account: HackersPub.ViewerQuery.Data.Viewer

    var id: String {
        account.id
    }
}

private enum ActorProfileTab: String, CaseIterable, Identifiable {
    case posts
    case notes
    case articles

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .posts:
            return NSLocalizedString("profile.tab.posts", comment: "Profile posts tab")
        case .notes:
            return NSLocalizedString("profile.tab.notes", comment: "Profile notes tab")
        case .articles:
            return NSLocalizedString("profile.tab.articles", comment: "Profile articles tab")
        }
    }

    var emptyTitle: String {
        switch self {
        case .posts:
            return NSLocalizedString("profile.empty.posts", comment: "Empty profile posts message")
        case .notes:
            return NSLocalizedString("profile.empty.notes", comment: "Empty profile notes message")
        case .articles:
            return NSLocalizedString("profile.empty.articles", comment: "Empty profile articles message")
        }
    }
}

private struct ActorProfileTabPageState {
    var hasLoaded = false
    var isLoading = false
    var hasNextPage = false
    var endCursor: String?
    var errorMessage: String?
}

private struct ActorProfilePostListView<Post: PostProtocol & ReactionCapablePostProtocol>: View {
    let posts: [Post]
    let pageState: ActorProfileTabPageState
    let emptyTitle: String
    let onRetry: () -> Void
    let onLoadMore: () -> Void

    var body: some View {
        Group {
            if pageState.isLoading && posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let errorMessage = pageState.errorMessage, posts.isEmpty {
                VStack(spacing: 12) {
                    ContentUnavailableView(
                        NSLocalizedString("common.error", comment: "Error title"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )

                    Button(NSLocalizedString("common.retry", comment: "Retry button")) {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if pageState.hasLoaded && posts.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "doc.text")
                    .padding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(posts, id: \.id) { post in
                        PostView(
                            post: post,
                            showAuthor: true,
                            disableNavigation: false,
                            enableSneakPeek: true,
                            contentRenderMode: .lightweightText
                        )
                            .padding()
                            .onAppear {
                                if post.id == posts.last?.id && pageState.hasNextPage && !pageState.isLoading {
                                    onLoadMore()
                                }
                            }

                        Divider()
                    }

                    if pageState.isLoading {
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

struct ActorProfileView: View {
    let actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle

    @Environment(AuthManager.self) private var authManager

    @State private var actorData: HackersPub.ActorByHandleQuery.Data.ActorByHandle
    @State private var selectedTab: ActorProfileTab = .posts
    @State private var posts: [HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node] = []
    @State private var notes: [HackersPub.ActorNotesQuery.Data.ActorByHandle.Notes.Edge.Node] = []
    @State private var articles: [HackersPub.ActorArticlesQuery.Data.ActorByHandle.Articles.Edge.Node] = []
    @State private var postsPageState = ActorProfileTabPageState()
    @State private var notesPageState = ActorProfileTabPageState()
    @State private var articlesPageState = ActorProfileTabPageState()
    @State private var isPerformingAction = false
    @State private var relationshipActionErrorMessage: String?
    @State private var editableProfileAccount: EditableProfileAccount?

    init(actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle) {
        self.actor = actor
        _actorData = State(initialValue: actor)
        _posts = State(initialValue: actor.posts.edges.map { $0.node })
        _postsPageState = State(initialValue: ActorProfileTabPageState(
            hasLoaded: true,
            isLoading: false,
            hasNextPage: actor.posts.pageInfo.hasNextPage,
            endCursor: actor.posts.pageInfo.endCursor,
            errorMessage: nil
        ))
    }

    private var relationshipState: ActorRelationshipState {
        ActorRelationshipState(actor: actorData)
    }

    private var canShowRelationshipControls: Bool {
        authManager.isAuthenticated && !relationshipState.isViewer
    }

    private var followButtonTitle: String {
        relationshipState.viewerFollows
            ? NSLocalizedString("profile.action.unfollow", comment: "Unfollow actor")
            : NSLocalizedString("profile.action.follow", comment: "Follow actor")
    }

    @ViewBuilder
    private var profileTabContent: some View {
        switch selectedTab {
        case .posts:
            ActorProfilePostListView(
                posts: posts,
                pageState: postsPageState,
                emptyTitle: ActorProfileTab.posts.emptyTitle,
                onRetry: {
                    Task {
                        await fetchProfile(cachePolicy: .networkOnly)
                    }
                },
                onLoadMore: {
                    Task {
                        await loadMorePosts()
                    }
                }
            )
        case .notes:
            ActorProfilePostListView(
                posts: notes,
                pageState: notesPageState,
                emptyTitle: ActorProfileTab.notes.emptyTitle,
                onRetry: {
                    Task {
                        await loadNotes(reset: true, cachePolicy: .networkOnly)
                    }
                },
                onLoadMore: {
                    Task {
                        await loadMoreNotes()
                    }
                }
            )
        case .articles:
            ActorProfilePostListView(
                posts: articles,
                pageState: articlesPageState,
                emptyTitle: ActorProfileTab.articles.emptyTitle,
                onRetry: {
                    Task {
                        await loadArticles(reset: true, cachePolicy: .networkOnly)
                    }
                },
                onLoadMore: {
                    Task {
                        await loadMoreArticles()
                    }
                }
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    KFImage(URL(string: actorData.avatarUrl))
                        .placeholder {
                            Color.gray.opacity(0.2)
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())

                    VStack(spacing: 8) {
                        if let name = actorData.name {
                            HTMLTextView(html: name, font: .title)
                        }

                        HStack(spacing: 8) {
                            Text(actorData.handle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if canShowRelationshipControls && (relationshipState.followsViewer || relationshipState.viewerBlocks) {
                                ActorRelationshipTagsView(
                                    followsViewer: relationshipState.followsViewer,
                                    viewerBlocks: relationshipState.viewerBlocks
                                )
                            }
                        }
                    }

                    if relationshipState.isViewer {
                        Button {
                            presentProfileEditor()
                        } label: {
                            Label(NSLocalizedString("profile.edit.title", comment: "Edit profile button"), systemImage: "pencil")
                        }
                        .buttonStyle(.borderedProminent)
                    } else if canShowRelationshipControls {
                        if relationshipState.viewerFollows {
                            Button {
                                performRelationshipAction(.unfollow)
                            } label: {
                                if isPerformingAction {
                                    ProgressView()
                                } else {
                                    Text(followButtonTitle)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .foregroundStyle(.white)
                            .frame(width: 200)
                            .disabled(isPerformingAction)
                        } else {
                            Button {
                                performRelationshipAction(.follow)
                            } label: {
                                if isPerformingAction {
                                    ProgressView()
                                } else {
                                    Text(followButtonTitle)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(width: 200)
                            .disabled(isPerformingAction)
                        }
                    }

                    if let bio = actorData.bio {
                        ProfileBioContentView(html: bio)
                            .padding(.horizontal)
                    }
                }
                .padding()

                Divider()

                Picker(NSLocalizedString("profile.tab.selector", comment: "Profile tab selector"), selection: $selectedTab) {
                    ForEach(ActorProfileTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)

                profileTabContent
            }
        }
        .task(id: selectedTab) {
            await loadSelectedTabIfNeeded()
        }
        .onChange(of: selectedTab) {
            notesPageState.errorMessage = nil
            articlesPageState.errorMessage = nil
        }
        .toolbar {
            if canShowRelationshipControls {
                ToolbarItem(placement: .topBarTrailing) {
                    ActorProfileActionMenu(
                        state: relationshipState,
                        isPerformingAction: isPerformingAction,
                        onAction: performRelationshipAction
                    )
                }
            }
        }
        .alert(
            NSLocalizedString("actorRelation.error.title", comment: "Actor relation action error title"),
            isPresented: Binding(
                get: { relationshipActionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        relationshipActionErrorMessage = nil
                    }
                }
            )
        ) {
            Button(NSLocalizedString("compose.error.ok", comment: "OK button"), role: .cancel) {
                relationshipActionErrorMessage = nil
            }
        } message: {
            Text(relationshipActionErrorMessage ?? "")
        }
        .sheet(item: $editableProfileAccount) { item in
            NavigationStack {
                EditProfileView(account: item.account) {
                    Task {
                        await fetchProfile(cachePolicy: .networkOnly)
                    }
                }
            }
        }
        .refreshable {
            await refreshProfile()
        }
        .task {
            await fetchProfile(cachePolicy: .networkFirst)
        }
        .onChange(of: actor.id) {
            resetTabs(for: actor)
            Task {
                await fetchProfile(cachePolicy: .networkFirst)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func performRelationshipAction(_ action: ActorRelationshipAction) {
        guard canShowRelationshipControls else { return }
        guard !isPerformingAction else { return }

        Task {
            isPerformingAction = true
            defer { isPerformingAction = false }

            do {
                try await ActorRelationshipService.perform(action: action, actorId: relationshipState.actorId)
                await fetchProfile(cachePolicy: .networkOnly)
            } catch {
                relationshipActionErrorMessage = error.localizedDescription
            }
        }
    }

    private func presentProfileEditor() {
        Task {
            if authManager.currentAccount == nil {
                await authManager.fetchViewer()
            }
            guard let account = authManager.currentAccount else { return }
            editableProfileAccount = EditableProfileAccount(account: account)
        }
    }

    private func resetTabs(for actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle) {
        actorData = actor
        selectedTab = .posts
        posts = actor.posts.edges.map { $0.node }
        postsPageState = ActorProfileTabPageState(
            hasLoaded: true,
            isLoading: false,
            hasNextPage: actor.posts.pageInfo.hasNextPage,
            endCursor: actor.posts.pageInfo.endCursor,
            errorMessage: nil
        )
        notes = []
        notesPageState = ActorProfileTabPageState()
        articles = []
        articlesPageState = ActorProfileTabPageState()
    }

    private func fetchProfile(cachePolicy: CachePolicy.Query.SingleResponse) async {
        postsPageState.isLoading = selectedTab == .posts
        defer {
            postsPageState.isLoading = false
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorByHandleQuery(handle: actorData.handle, after: nil),
                cachePolicy: cachePolicy
            )
            if let refreshedActor = response.data?.actorByHandle {
                actorData = refreshedActor
                posts = refreshedActor.posts.edges.map { $0.node }
                postsPageState.hasLoaded = true
                postsPageState.hasNextPage = refreshedActor.posts.pageInfo.hasNextPage
                postsPageState.endCursor = refreshedActor.posts.pageInfo.endCursor
                postsPageState.errorMessage = nil
            }
        } catch {
            if posts.isEmpty {
                postsPageState.errorMessage = error.localizedDescription
            }
            print("Error fetching actor profile: \(error)")
        }
    }

    private func refreshProfile() async {
        postsPageState.isLoading = selectedTab == .posts
        defer {
            postsPageState.isLoading = false
        }

        do {
            let response = try await apolloClient.fetchAfterClearingCache(
                query: HackersPub.ActorByHandleQuery(handle: actorData.handle, after: nil)
            )
            if let refreshedActor = response.data?.actorByHandle {
                actorData = refreshedActor
                posts = refreshedActor.posts.edges.map { $0.node }
                postsPageState.hasLoaded = true
                postsPageState.hasNextPage = refreshedActor.posts.pageInfo.hasNextPage
                postsPageState.endCursor = refreshedActor.posts.pageInfo.endCursor
                postsPageState.errorMessage = nil
            }
        } catch {
            if posts.isEmpty {
                postsPageState.errorMessage = error.localizedDescription
            }
            print("Error refreshing actor profile: \(error)")
        }

        switch selectedTab {
        case .posts:
            break
        case .notes:
            await loadNotes(reset: true, cachePolicy: .networkOnly)
        case .articles:
            await loadArticles(reset: true, cachePolicy: .networkOnly)
        }
    }

    private func loadSelectedTabIfNeeded() async {
        switch selectedTab {
        case .posts:
            if !postsPageState.hasLoaded {
                await fetchProfile(cachePolicy: .networkFirst)
            }
        case .notes:
            if !notesPageState.hasLoaded {
                await loadNotes(reset: true, cachePolicy: .networkFirst)
            }
        case .articles:
            if !articlesPageState.hasLoaded {
                await loadArticles(reset: true, cachePolicy: .networkFirst)
            }
        }
    }

    private func loadMorePosts() async {
        guard let cursor = postsPageState.endCursor, postsPageState.hasNextPage, !postsPageState.isLoading else { return }

        postsPageState.isLoading = true
        defer { postsPageState.isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorByHandleQuery(handle: actorData.handle, after: .some(cursor)),
                cachePolicy: .networkFirst
            )
            if let refreshedActor = response.data?.actorByHandle {
                posts.append(contentsOf: refreshedActor.posts.edges.map { $0.node })
                postsPageState.hasLoaded = true
                postsPageState.hasNextPage = refreshedActor.posts.pageInfo.hasNextPage
                postsPageState.endCursor = refreshedActor.posts.pageInfo.endCursor
                postsPageState.errorMessage = nil
            }
        } catch {
            postsPageState.errorMessage = error.localizedDescription
            print("Error loading more actor posts: \(error)")
        }
    }

    private func loadNotes(reset: Bool, cachePolicy: CachePolicy.Query.SingleResponse) async {
        guard !notesPageState.isLoading else { return }
        if !reset {
            guard notesPageState.hasNextPage, notesPageState.endCursor != nil else { return }
        }

        notesPageState.isLoading = true
        defer { notesPageState.isLoading = false }

        let after: GraphQLNullable<String> = reset ? nil : notesPageState.endCursor.map { .some($0) } ?? nil

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorNotesQuery(handle: actorData.handle, after: after),
                cachePolicy: cachePolicy
            )
            if let notesConnection = response.data?.actorByHandle?.notes {
                let nextNotes = notesConnection.edges.map { $0.node }
                notes = reset ? nextNotes : notes + nextNotes
                notesPageState.hasLoaded = true
                notesPageState.hasNextPage = notesConnection.pageInfo.hasNextPage
                notesPageState.endCursor = notesConnection.pageInfo.endCursor
                notesPageState.errorMessage = nil
            }
        } catch {
            if notes.isEmpty {
                notesPageState.errorMessage = error.localizedDescription
            }
            print("Error loading actor notes: \(error)")
        }
    }

    private func loadMoreNotes() async {
        guard notesPageState.hasNextPage, notesPageState.endCursor != nil else { return }
        await loadNotes(reset: false, cachePolicy: .networkFirst)
    }

    private func loadArticles(reset: Bool, cachePolicy: CachePolicy.Query.SingleResponse) async {
        guard !articlesPageState.isLoading else { return }
        if !reset {
            guard articlesPageState.hasNextPage, articlesPageState.endCursor != nil else { return }
        }

        articlesPageState.isLoading = true
        defer { articlesPageState.isLoading = false }

        let after: GraphQLNullable<String> = reset ? nil : articlesPageState.endCursor.map { .some($0) } ?? nil

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorArticlesQuery(handle: actorData.handle, after: after),
                cachePolicy: cachePolicy
            )
            if let articlesConnection = response.data?.actorByHandle?.articles {
                let nextArticles = articlesConnection.edges.map { $0.node }
                articles = reset ? nextArticles : articles + nextArticles
                articlesPageState.hasLoaded = true
                articlesPageState.hasNextPage = articlesConnection.pageInfo.hasNextPage
                articlesPageState.endCursor = articlesConnection.pageInfo.endCursor
                articlesPageState.errorMessage = nil
            }
        } catch {
            if articles.isEmpty {
                articlesPageState.errorMessage = error.localizedDescription
            }
            print("Error loading actor articles: \(error)")
        }
    }

    private func loadMoreArticles() async {
        guard articlesPageState.hasNextPage, articlesPageState.endCursor != nil else { return }
        await loadArticles(reset: false, cachePolicy: .networkFirst)
    }
}
