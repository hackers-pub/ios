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

struct ActorProfileView: View {
    let actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle

    @Environment(AuthManager.self) private var authManager

    @State private var actorData: HackersPub.ActorByHandleQuery.Data.ActorByHandle
    @State private var posts: [HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node] = []
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var isPerformingAction = false
    @State private var relationshipActionErrorMessage: String?

    init(actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle) {
        self.actor = actor
        _actorData = State(initialValue: actor)
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

                    if canShowRelationshipControls {
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
                        HTMLContentView(html: bio, media: [])
                            .padding(.horizontal)
                    }
                }
                .padding()

                Divider()

                if !posts.isEmpty {
                    LazyVStack(spacing: 0) {
                        ForEach(posts, id: \.id) { post in
                            PostView(post: post, showAuthor: true, disableNavigation: false, enableSneakPeek: true)
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
        .refreshable {
            await fetchProfile(cachePolicy: .networkOnly)
        }
        .task {
            await fetchProfile(cachePolicy: .networkFirst)
        }
        .onChange(of: actor.id) {
            actorData = actor
            Task {
                await fetchProfile(cachePolicy: .networkFirst)
            }
        }
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

    private func fetchProfile(cachePolicy: CachePolicy.Query.SingleResponse) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorByHandleQuery(handle: actorData.handle, after: nil),
                cachePolicy: cachePolicy
            )
            if let refreshedActor = response.data?.actorByHandle {
                actorData = refreshedActor
                posts = refreshedActor.posts.edges.map { $0.node }
                hasNextPage = refreshedActor.posts.pageInfo.hasNextPage
                endCursor = refreshedActor.posts.pageInfo.endCursor
            }
        } catch {
            print("Error fetching actor profile: \(error)")
        }
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorByHandleQuery(handle: actorData.handle, after: .some(cursor))
            )
            if let refreshedActor = response.data?.actorByHandle {
                posts.append(contentsOf: refreshedActor.posts.edges.map { $0.node })
                hasNextPage = refreshedActor.posts.pageInfo.hasNextPage
                endCursor = refreshedActor.posts.pageInfo.endCursor
            }
        } catch {
            print("Error loading more actor posts: \(error)")
        }
    }
}
