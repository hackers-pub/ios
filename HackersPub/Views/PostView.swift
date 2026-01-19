import SwiftUI
import Kingfisher
@preconcurrency import Apollo

protocol EngagementStatsProtocol {
    var replies: Int { get }
    var reactions: Int { get }
    var shares: Int { get }
    var quotes: Int { get }
}

protocol PostProtocol {
    associatedtype ActorType: ActorProtocol
    associatedtype MediaType: MediaProtocol
    associatedtype SharedPostType: PostProtocol
    associatedtype EngagementStatsType: EngagementStatsProtocol

    var id: String { get }
    var name: String? { get }
    var published: String { get }
    var summary: String? { get }
    var content: String { get }
    var excerpt: String { get }
    var url: String? { get }
    var actor: ActorType { get }
    var media: [MediaType] { get }
    var sharedPost: SharedPostType? { get }
    var engagementStats: EngagementStatsType { get }
    var viewerHasShared: Bool { get }

    var mentionedHandles: [String] { get }
    var isArticle: Bool { get }
}

protocol ActorProtocol {
    var id: String { get }
    var name: String? { get }
    var handle: String { get }
    var avatarUrl: String { get }
}

protocol MediaProtocol {
    var url: String { get }
    var thumbnailUrl: String? { get }
    var alt: String? { get }
    var width: Int? { get }
    var height: Int? { get }
}

struct RepostIndicator<Actor: ActorProtocol>: View {
    let actor: Actor
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.2.squarepath")
                .font(.caption)

            Button {
                navigationCoordinator.navigateToProfile(handle: actor.handle)
            } label: {
                KFImage(URL(string: actor.avatarUrl))
                    .placeholder {
                        Color.gray.opacity(0.2)
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                navigationCoordinator.navigateToProfile(handle: actor.handle)
            } label: {
                if let name = actor.name {
                    HTMLTextView(html: name, font: .caption)
                } else {
                    Text(actor.handle)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            Text("reposted")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

struct PostView<P: PostProtocol>: View {
    let post: P
    let showAuthor: Bool
    let disableNavigation: Bool
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @State private var showingReplyView = false
    @State private var isSharing = false
    @State private var hasShared: Bool
    @State private var sharesCount: Int
    @State private var markdownMaxLength = UserDefaults.standard.integer(forKey: "markdownMaxLength") {
        didSet {
            UserDefaults.standard.set(markdownMaxLength, forKey: "markdownMaxLength")
        }
    }

    init(post: P, showAuthor: Bool = true, disableNavigation: Bool = false) {
        self.post = post
        self.showAuthor = showAuthor
        self.disableNavigation = disableNavigation
        self._hasShared = State(initialValue: post.viewerHasShared)
        self._sharesCount = State(initialValue: post.engagementStats.shares)
    }

    private func getContent(content: String) -> String {
        if self.markdownMaxLength != 0 {
            return content.htmlTruncated(limit: self.markdownMaxLength)
        }

        return content
    }

    private func toggleShare() async {
        guard !isSharing else { return }
        isSharing = true
        defer { isSharing = false }

        do {
            if hasShared {
                // Unshare
                let response = try await apolloClient.perform(
                    mutation: HackersPub.UnsharePostMutation(postId: post.id)
                )
                if let payload = response.data?.unsharePost.asUnsharePostPayload {
                    hasShared = payload.originalPost.viewerHasShared
                    sharesCount = payload.originalPost.engagementStats.shares
                }
            } else {
                // Share
                let response = try await apolloClient.perform(
                    mutation: HackersPub.SharePostMutation(postId: post.id)
                )
                if let payload = response.data?.sharePost.asSharePostPayload {
                    hasShared = payload.originalPost.viewerHasShared
                    sharesCount = payload.originalPost.engagementStats.shares
                }
            }
        } catch {
            print("Error toggling share: \(error)")
        }
    }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                // Show repost indicator
                if showAuthor && post.sharedPost != nil {
                    RepostIndicator(actor: post.actor)
                }

                if showAuthor && post.sharedPost == nil {
                    HStack(spacing: 8) {
                        Button {
                            navigationCoordinator.navigateToProfile(handle: post.actor.handle)
                        } label: {
                            KFImage(URL(string: post.actor.avatarUrl))
                                .placeholder {
                                    Color.gray.opacity(0.2)
                                }
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            navigationCoordinator.navigateToProfile(handle: post.actor.handle)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                if let name = post.actor.name {
                                    HTMLTextView(html: name, font: .headline)
                                }
                                Text(post.actor.handle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }

            if let sharedPost = post.sharedPost {
                // Display shared post
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            navigationCoordinator.navigateToProfile(handle: sharedPost.actor.handle)
                        } label: {
                            KFImage(URL(string: sharedPost.actor.avatarUrl))
                                .placeholder {
                                    Color.gray.opacity(0.2)
                                }
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            navigationCoordinator.navigateToProfile(handle: sharedPost.actor.handle)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                if let name = sharedPost.actor.name {
                                    HTMLTextView(html: name, font: .headline)
                                }
                                Text(sharedPost.actor.handle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }

                    if let name = sharedPost.name {
                        Text(name)
                            .font(.headline)
                    }
                    
                    let content = self.getContent(content: post.content)
                    HTMLContentView(
                        html: content,
                        media: sharedPost.media.map { MediaItem(url: $0.url, thumbnailUrl: $0.thumbnailUrl, alt: $0.alt, width: $0.width, height: $0.height) },
                        onTap: !disableNavigation ? {
                            navigationCoordinator.navigateToPost(id: post.id)
                        } : nil
                    )

                    Text(DateFormatHelper.relativeTime(from: sharedPost.published))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if post.isArticle {
                // Display article summary with navigation link
                NavigationLink {
                    ArticleDetailView(post: post)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        if let name = post.name {
                            Text(name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        if let summary = post.summary {
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        HStack {
                            Text("Read article")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            } else {
                // Display original post content
                if let name = post.name {
                    Text(name)
                        .font(.headline)
                }
                
                let content = self.getContent(content: post.content)
                HTMLContentView(
                    html: content,
                    media: post.media.map { MediaItem(url: $0.url, thumbnailUrl: $0.thumbnailUrl, alt: $0.alt, width: $0.width, height: $0.height) },
                    onTap: !disableNavigation && !post.isArticle ? {
                        navigationCoordinator.navigateToPost(id: post.id)
                    } : nil
                )
            }

            Text(DateFormatHelper.relativeTime(from: post.published))
                .font(.caption)
                .foregroundStyle(.secondary)

                // Action buttons with engagement stats
                HStack(spacing: 16) {
                    Button {
                        showingReplyView = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left")
                            if post.engagementStats.replies > 0 {
                                Text("\(post.engagementStats.replies)")
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.borderless)

                    if post.engagementStats.reactions > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                            Text("\(post.engagementStats.reactions)")
                                .font(.caption)
                        }
                    }

                    if sharesCount > 0 || AuthManager.shared.currentAccount != nil {
                        Button {
                            Task {
                                await toggleShare()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isSharing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.2.squarepath")
                                        .foregroundStyle(hasShared ? Color.green : Color.secondary)
                                }
                                if sharesCount > 0 {
                                    Text("\(sharesCount)")
                                        .font(.caption)
                                        .foregroundStyle(hasShared ? Color.green : Color.secondary)
                                }
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(isSharing || AuthManager.shared.currentAccount == nil)
                    }

                    if post.engagementStats.quotes > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "quote.bubble")
                            Text("\(post.engagementStats.quotes)")
                                .font(.caption)
                        }
                    }

                    Spacer()

                    if let urlString = post.url, let url = URL(string: urlString) {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .background(
                Group {
                    if !disableNavigation && !post.isArticle {
                        NavigationLink(destination: PostDetailView(postId: post.id)) {
                            Color.clear
                        }
                        .opacity(0)
                        .buttonStyle(.plain)
                    }
                }
            )
        }
        .sheet(isPresented: $showingReplyView) {
            ComposeView(
                replyToPostId: post.id,
                replyToActor: post.actor.handle,
                initialMentions: getMentionHandles(
                    from: post,
                    excludingHandle: AuthManager.shared.currentAccount?.handle
                )
            )
        }
    }
}
