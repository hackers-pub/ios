@preconcurrency import Apollo
import SwiftUI

struct TimelineEmptyState: View {
    let retry: () -> Void
    let refresh: () async -> Void

    var body: some View {
        ScrollView {
            ContentUnavailableView {
                Label(
                    NSLocalizedString("timeline.empty.title", comment: "Empty timeline title"),
                    systemImage: "text.line.first.and.arrowtriangle.forward"
                )
            } description: {
                Text(NSLocalizedString("timeline.empty.description", comment: "Empty timeline description"))
            } actions: {
                Button(NSLocalizedString("common.retry", comment: "Retry button")) {
                    retry()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
        }
        .refreshable {
            await refresh()
        }
    }
}

struct LoadNewerItemsRow: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView()
                } else {
                    Label(NSLocalizedString("timeline.loadNewer", comment: "Load newer items"), systemImage: "arrow.up")
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.Actor: ActorProtocol {}
extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.LastSharer: ActorProtocol {}
extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge {
    var timelineListID: String {
        node.id
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost
    typealias EngagementStatsType = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost? {
        nil
    }

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.Actor: ActorProtocol {}
extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.LastSharer: ActorProtocol {}
extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge {
    var timelineListID: String {
        node.id
    }
}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost
    typealias EngagementStatsType = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost? {
        nil
    }

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.SharedPost.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node.QuotedPost.Medium: MediaProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node: PostProtocol {
    typealias SharedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.QuotedPost
    typealias EngagementStatsType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.EngagementStats

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.Actor: ActorProtocol {}
extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.LastSharer: ActorProtocol {}
extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge {
    var timelineListID: String {
        node.id
    }
}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.Medium: MediaProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost: PostProtocol {
    typealias SharedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost
    typealias QuotedPostType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.QuotedPost
    typealias EngagementStatsType = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.EngagementStats
    var sharedPost: HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost? {
        nil
    }

    var isArticle: Bool {
        return __typename == "Article"
    }

    var mentionedHandles: [String] {
        return mentions.edges.map { $0.node.handle }
    }
}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.Actor: ActorProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.Medium: MediaProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.SharedPost.QuotedPost
    .Medium: MediaProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.QuotedPost: QuotedPostProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.QuotedPost.Actor: ActorProtocol {}

extension HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node.QuotedPost.Medium: MediaProtocol {}

struct TimelineView: View {
    @Binding var showingComposeView: Bool
    @State private var controller = TimelineFeedController<HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge>(
        source: .publicTimeline
    )
    @State private var scrollPositionID: String?
    @State private var showingSettings = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        _showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .global)) {
            TimelineFeedContent(
                timelineState: controller.timelineState,
                scrollPositionID: $scrollPositionID,
                edgeID: \.timelineListID,
                edgeCursor: \.cursor,
                post: \.node,
                sharer: \.lastSharer,
                added: \.added,
                retry: { controller.retry() },
                refresh: { await controller.refresh() },
                loadNewer: { controller.loadNewer() },
                loadMore: { controller.loadMore() }
            )
            .navigationTitle(NSLocalizedString("timeline.fediverse", comment: "Fediverse navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await controller.supervise()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshTimeline"))) { _ in
                controller.requestRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .postContentDidChange)) { notification in
                controller.handlePostContentNotification(notification)
            }
            .onDisappear {
                controller.cancelAll()
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
        }
    }
}

struct PersonalTimelineView: View {
    @Binding var showingComposeView: Bool
    @State private var controller = TimelineFeedController<HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge>(
        source: .personalTimeline
    )
    @State private var scrollPositionID: String?
    @State private var showingSettings = false
    @State private var showingArticleEditor = false
    @State private var showingArticleDrafts = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        _showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .timeline)) {
            TimelineFeedContent(
                timelineState: controller.timelineState,
                scrollPositionID: $scrollPositionID,
                edgeID: \.timelineListID,
                edgeCursor: \.cursor,
                post: \.node,
                sharer: \.lastSharer,
                added: \.added,
                retry: { controller.retry() },
                refresh: { await controller.refresh() },
                loadNewer: { controller.loadNewer() },
                loadMore: { controller.loadMore() }
            )
            .navigationTitle(NSLocalizedString("nav.timeline", comment: "Timeline navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await controller.supervise()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshTimeline"))) { _ in
                controller.requestRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .postContentDidChange)) { notification in
                controller.handlePostContentNotification(notification)
            }
            .onDisappear {
                controller.cancelAll()
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

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingComposeView = true
                        } label: {
                            Label(NSLocalizedString("common.newPost", comment: "New post button"), systemImage: "square.and.pencil")
                        }
                        Button {
                            showingArticleEditor = true
                        } label: {
                            Label(NSLocalizedString("article.new", comment: "New article"), systemImage: "doc.badge.plus")
                        }
                        Button {
                            showingArticleDrafts = true
                        } label: {
                            Label(NSLocalizedString("article.drafts", comment: "Article drafts"), systemImage: "tray.full")
                        }
                    } label: {
                        Label(NSLocalizedString("common.compose", comment: "Compose menu"), systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingArticleEditor) {
                ArticleEditorView {
                    showingArticleEditor = false
                    controller.retry()
                }
            }
            .sheet(isPresented: $showingArticleDrafts) {
                ArticleDraftListView()
            }
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
        }
    }
}

struct LocalTimelineView: View {
    @Binding var showingComposeView: Bool
    @State private var controller = TimelineFeedController<HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge>(
        source: .localTimeline
    )
    @State private var scrollPositionID: String?
    @State private var showingSettings = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        _showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .local)) {
            TimelineFeedContent(
                timelineState: controller.timelineState,
                scrollPositionID: $scrollPositionID,
                edgeID: \.timelineListID,
                edgeCursor: \.cursor,
                post: \.node,
                sharer: \.lastSharer,
                added: \.added,
                retry: { controller.retry() },
                refresh: { await controller.refresh() },
                loadNewer: { controller.loadNewer() },
                loadMore: { controller.loadMore() }
            )
            .navigationTitle(NSLocalizedString("timeline.hackersPub", comment: "Hackers' Pub navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                #if DEBUG
                    await controller.supervise(
                        initialLoadEnabled: !UITestLaunchConfiguration.disablesRootTimelineNetwork
                    )
                #else
                    await controller.supervise()
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshTimeline"))) { _ in
                controller.requestRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .postContentDidChange)) { notification in
                controller.handlePostContentNotification(notification)
            }
            .onDisappear {
                controller.cancelAll()
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
        }
    }
}
