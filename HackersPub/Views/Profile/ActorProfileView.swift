import Kingfisher
import SwiftUI

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

enum ActorProfileTab: String, CaseIterable, Identifiable {
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

private struct ActorProfilePostListView<Post: PostProtocol & ReactionCapablePostProtocol>: View {
    let posts: [Post]
    let pageState: ActorProfileTabPageState
    let emptyTitle: String
    let onRetry: () -> Void
    let onLoadNewer: () -> Void
    let onLoadMore: () -> Void

    var body: some View {
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
                if pageState.hasPreviousPage && !posts.isEmpty {
                    LoadNewerItemsRow(isLoading: pageState.isLoading) {
                        onLoadNewer()
                    }
                    Divider()
                }

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

struct ActorProfileView: View {
    let actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle

    @Environment(AuthManager.self) private var authManager

    @State var actorData: HackersPub.ActorByHandleQuery.Data.ActorByHandle
    @State var selectedTab: ActorProfileTab = .posts
    @State var posts: [HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node] = []
    @State var notes: [HackersPub.ActorNotesQuery.Data.ActorByHandle.Notes.Edge.Node] = []
    @State var articles: [HackersPub.ActorArticlesQuery.Data.ActorByHandle.Articles.Edge.Node] = []
    @State var postsPageState = ActorProfileTabPageState()
    @State var notesPageState = ActorProfileTabPageState()
    @State var articlesPageState = ActorProfileTabPageState()
    @State var profilePostsRequestCoordinator: ActorProfilePostRequestCoordinator
    @State var notesRequestCoordinator: ActorProfileTabRequestCoordinator
    @State var articlesRequestCoordinator: ActorProfileTabRequestCoordinator
    @State private var notesLoadTask: Task<Void, Never>?
    @State private var articlesLoadTask: Task<Void, Never>?
    @State private var localRelationshipState: ActorRelationshipState?
    @State private var relationshipActionCoordinator = ProfileRelationshipActionCoordinator()
    @State private var relationshipActionTask: Task<Void, Never>?
    @State private var relationshipRetryGeneration: UInt64 = 0
    @State private var relationshipActionErrorMessage: String?
    @State private var failedRelationshipRetry: ActorProfileRelationshipRetry?
    @State private var editableProfileAccount: EditableProfileAccount?
    @State private var postContentGeneration = 0

    init(actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle) {
        self.actor = actor
        _actorData = State(initialValue: actor)
        _posts = State(initialValue: actor.posts.edges.map { $0.node })
        _postsPageState = State(initialValue: ActorProfileTabPageState(
            hasLoaded: true,
            isLoading: false,
            hasPreviousPage: actor.posts.pageInfo.hasPreviousPage,
            hasNextPage: actor.posts.pageInfo.hasNextPage,
            startCursor: actor.posts.pageInfo.startCursor,
            endCursor: actor.posts.pageInfo.endCursor,
            errorMessage: nil
        ))
        _profilePostsRequestCoordinator = State(initialValue: ActorProfilePostRequestCoordinator(
            profileID: actor.id,
            hasLoadedInitial: true
        ))
        _notesRequestCoordinator = State(initialValue: ActorProfileTabRequestCoordinator(actorID: actor.id))
        _articlesRequestCoordinator = State(initialValue: ActorProfileTabRequestCoordinator(actorID: actor.id))
    }

    private var relationshipState: ActorRelationshipState {
        if let localRelationshipState, localRelationshipState.actorId == actorData.id {
            return localRelationshipState
        }
        return ActorRelationshipState(actor: actorData)
    }

    private var isPerformingAction: Bool {
        relationshipActionCoordinator.isPerformingAction
    }

    private var failedRelationshipRetryAction: ActorRelationshipAction? {
        failedRelationshipRetry?.actionIfCurrent(
            actorID: actorData.id,
            generation: relationshipRetryGeneration
        )
    }

    private var selectedTabTaskID: String {
        "\(actor.id)|\(selectedTab.rawValue)"
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
                        await refreshProfile()
                    }
                },
                onLoadNewer: {
                    Task {
                        await loadNewerPosts()
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
                    notesLoadTask?.cancel()
                    notesLoadTask = Task {
                        await refreshNotes()
                    }
                },
                onLoadNewer: {
                    notesLoadTask?.cancel()
                    notesLoadTask = Task {
                        await loadNewerNotes()
                    }
                },
                onLoadMore: {
                    notesLoadTask?.cancel()
                    notesLoadTask = Task {
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
                    articlesLoadTask?.cancel()
                    articlesLoadTask = Task {
                        await refreshArticles()
                    }
                },
                onLoadNewer: {
                    articlesLoadTask?.cancel()
                    articlesLoadTask = Task {
                        await loadNewerArticles()
                    }
                },
                onLoadMore: {
                    articlesLoadTask?.cancel()
                    articlesLoadTask = Task {
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
                    } else if canShowRelationshipControls && !relationshipState.viewerBlocks {
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
        .task(id: selectedTabTaskID) {
            await loadSelectedTabIfNeeded()
        }
        .onChange(of: selectedTab) {
            notesPageState.errorMessage = nil
            articlesPageState.errorMessage = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .postContentDidChange)) { notification in
            handlePostContentNotification(notification)
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
                get: {
                    relationshipActionErrorMessage != nil
                        && failedRelationshipRetryAction != nil
                },
                set: { isPresented in
                    if !isPresented {
                        relationshipActionErrorMessage = nil
                        failedRelationshipRetry = nil
                    }
                }
            )
        ) {
            if let failedRelationshipRetryAction {
                Button(NSLocalizedString("common.retry", comment: "Retry button")) {
                    let action = failedRelationshipRetryAction
                    relationshipActionErrorMessage = nil
                    failedRelationshipRetry = nil
                    performRelationshipAction(action)
                }
            }
            Button(NSLocalizedString("compose.error.ok", comment: "OK button"), role: .cancel) {
                relationshipActionErrorMessage = nil
                failedRelationshipRetry = nil
            }
        } message: {
            Text(relationshipActionErrorMessage ?? "")
        }
        .sheet(item: $editableProfileAccount) { item in
            NavigationStack {
                EditProfileView(account: item.account) {
                    Task {
                        await refreshProfile()
                    }
                }
            }
        }
        .refreshable {
            await refreshProfile()
        }
        .task(id: actor.id) {
            activateProfileIfNeeded()
        }
        .toolbar(.hidden, for: .tabBar)
    }

    @MainActor
    private func handlePostContentNotification(_ notification: Notification) {
        guard let event = PostContentEventCenter.event(from: notification) else { return }
        let removedPostIDs: Set<String>
        switch event {
        case let .postDeleted(postID):
            removedPostIDs = [postID]
        case .replyCreated, .bookmarkChanged:
            return
        }
        let rows = posts.map {
            postListItemIdentity(rowID: $0.id, post: $0)
        } + notes.map {
            postListItemIdentity(rowID: $0.id, post: $0)
        } + articles.map {
            postListItemIdentity(rowID: $0.id, post: $0)
        }
        let action = PostContentListEventRouter.route(
            event,
            host: .actorProfile,
            rows: rows,
            eventGeneration: postContentGeneration,
            activeGeneration: postContentGeneration
        )
        guard case .remove = action else { return }
        postContentGeneration += 1
        posts.removeAll { removedPostIDs.contains($0.id) || removedPostIDs.contains($0.sharedPost?.id ?? "") }
        notes.removeAll { removedPostIDs.contains($0.id) || removedPostIDs.contains($0.sharedPost?.id ?? "") }
        articles.removeAll { removedPostIDs.contains($0.id) || removedPostIDs.contains($0.sharedPost?.id ?? "") }
    }

    private func performRelationshipAction(_ action: ActorRelationshipAction) {
        guard canShowRelationshipControls else { return }
        let request = relationshipActionCoordinator.begin(
            action: action,
            actorID: relationshipState.actorId
        )
        let retryGeneration = relationshipRetryGeneration
        failedRelationshipRetry = nil

        relationshipActionTask?.cancel()
        relationshipActionTask = Task {
            do {
                try Task.checkCancellation()
                let receipt = try await ActorRelationshipService.perform(
                    action: action,
                    actorId: request.actorID
                )
                try Task.checkCancellation()
                guard let updatedRelationship = relationshipActionCoordinator.apply(
                    receipt,
                    for: request,
                    to: relationshipState
                ) else {
                    return
                }
                localRelationshipState = updatedRelationship
            } catch is CancellationError {
                _ = relationshipActionCoordinator.finishFailure(for: request)
            } catch {
                guard relationshipActionCoordinator.finishFailure(for: request),
                      request.actorID == actorData.id,
                      retryGeneration == relationshipRetryGeneration
                else {
                    return
                }
                failedRelationshipRetry = ActorProfileRelationshipRetry(
                    action: action,
                    actorID: request.actorID,
                    generation: retryGeneration
                )
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

    private func activateProfileIfNeeded() {
        guard profilePostsRequestCoordinator.activate(
            profileID: actor.id,
            hasLoadedInitial: true
        ) else {
            return
        }
        resetTabs(for: actor)
    }

    private func resetTabs(for actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle) {
        relationshipActionCoordinator.invalidate()
        relationshipActionTask?.cancel()
        relationshipActionTask = nil
        relationshipRetryGeneration &+= 1
        localRelationshipState = nil
        failedRelationshipRetry = nil
        relationshipActionErrorMessage = nil
        notesLoadTask?.cancel()
        notesLoadTask = nil
        articlesLoadTask?.cancel()
        articlesLoadTask = nil
        notesRequestCoordinator.reset(actorID: actor.id)
        articlesRequestCoordinator.reset(actorID: actor.id)
        actorData = actor
        selectedTab = .posts
        posts = actor.posts.edges.map { $0.node }
        postsPageState = ActorProfileTabPageState(
            hasLoaded: true,
            isLoading: false,
            hasPreviousPage: actor.posts.pageInfo.hasPreviousPage,
            hasNextPage: actor.posts.pageInfo.hasNextPage,
            startCursor: actor.posts.pageInfo.startCursor,
            endCursor: actor.posts.pageInfo.endCursor,
            errorMessage: nil
        )
        notes = []
        notesPageState = ActorProfileTabPageState()
        articles = []
        articlesPageState = ActorProfileTabPageState()
    }
}
