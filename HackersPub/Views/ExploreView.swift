import SwiftUI

enum ExploreScope: CaseIterable, Hashable {
    case local
    case global

    var displayName: String {
        switch self {
        case .local:
            NSLocalizedString("explore.scope.local", comment: "Local scope")
        case .global:
            NSLocalizedString("explore.scope.global", comment: "Global scope")
        }
    }
}

struct ExploreView: View {
    @Binding var showingComposeView: Bool
    @State private var selectedScope: ExploreScope = .local
    @State private var localTimelineStore = ExploreTimelineScopeStore<LocalExploreTimelineEdge>()
    @State private var globalTimelineStore = ExploreTimelineScopeStore<GlobalExploreTimelineEdge>()
    @State private var showingSettings = false
    @State private var showingArticleEditor = false
    @State private var showingArticleDrafts = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager

    init(showingComposeView: Binding<Bool> = .constant(false)) {
        _showingComposeView = showingComposeView
    }

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .explore)) {
            Group {
                switch selectedScope {
                case .local:
                    ExploreTimelineContent(store: localTimelineStore, dataSource: .local) { edge in
                        PostView(
                            post: edge.node,
                            timelineSharer: edge.lastSharer,
                            timelineAdded: edge.added,
                            enableSneakPeek: true,
                            contentRenderMode: .lightweightText
                        )
                    }
                case .global:
                    ExploreTimelineContent(store: globalTimelineStore, dataSource: .global) { edge in
                        PostView(
                            post: edge.node,
                            timelineSharer: edge.lastSharer,
                            timelineAdded: edge.added,
                            enableSneakPeek: true,
                            contentRenderMode: .lightweightText
                        )
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav.explore", comment: "Explore navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    ViewerProfileButton()

                    Button {
                        showingSettings = true
                    } label: {
                        Label(NSLocalizedString("common.settings", comment: "Settings button"), systemImage: "gear")
                    }
                }

                ToolbarItem(placement: .principal) {
                    Picker(NSLocalizedString("explore.scope", comment: "Scope picker"), selection: $selectedScope) {
                        ForEach(ExploreScope.allCases, id: \.self) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if authManager.isAuthenticated {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showingComposeView = true
                            } label: {
                                Label(
                                    NSLocalizedString("common.newPost", comment: "New note button"),
                                    systemImage: "square.and.pencil"
                                )
                            }
                            Button {
                                showingArticleEditor = true
                            } label: {
                                Label(
                                    NSLocalizedString("article.new", comment: "New article"),
                                    systemImage: "doc.badge.plus"
                                )
                            }
                            Button {
                                showingArticleDrafts = true
                            } label: {
                                Label(
                                    NSLocalizedString("article.drafts", comment: "Article drafts"),
                                    systemImage: "tray.full"
                                )
                            }
                        } label: {
                            Label(NSLocalizedString("common.compose", comment: "Compose menu"), systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingArticleEditor) {
                ArticleEditorView {
                    showingArticleEditor = false
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
