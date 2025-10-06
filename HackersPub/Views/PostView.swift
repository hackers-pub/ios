import SwiftUI

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
    var url: String? { get }
    var actor: ActorType { get }
    var media: [MediaType] { get }
    var sharedPost: SharedPostType? { get }
    var engagementStats: EngagementStatsType { get }

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

struct PostView<P: PostProtocol>: View {
    let post: P
    let showAuthor: Bool
    let disableNavigation: Bool
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @State private var showingReplyView = false

    init(post: P, showAuthor: Bool = true, disableNavigation: Bool = false) {
        self.post = post
        self.showAuthor = showAuthor
        self.disableNavigation = disableNavigation
    }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                if showAuthor {
                    HStack(spacing: 8) {
                        Button {
                            navigationCoordinator.navigateToProfile(handle: post.actor.handle)
                        } label: {
                            CachedAsyncImage(url: URL(string: post.actor.avatarUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            if let name = post.actor.name {
                                HTMLTextView(html: name, font: .headline)
                            }
                            Text(post.actor.handle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if post.sharedPost != nil {
                            Image(systemName: "arrow.2.squarepath")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            if let sharedPost = post.sharedPost {
                // Display shared post
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            navigationCoordinator.navigateToProfile(handle: sharedPost.actor.handle)
                        } label: {
                            CachedAsyncImage(url: URL(string: sharedPost.actor.avatarUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            if let name = sharedPost.actor.name {
                                HTMLTextView(html: name, font: .subheadline)
                                    .fontWeight(.semibold)
                            }
                            Text(sharedPost.actor.handle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let name = sharedPost.name {
                        Text(name)
                            .font(.headline)
                    }
                    HTMLContentView(
                        html: sharedPost.content,
                        media: sharedPost.media.map { MediaItem(url: $0.url, thumbnailUrl: $0.thumbnailUrl, alt: $0.alt, width: $0.width, height: $0.height) }
                    )
                    Text(sharedPost.published)
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
                HTMLContentView(
                    html: post.content,
                    media: post.media.map { MediaItem(url: $0.url, thumbnailUrl: $0.thumbnailUrl, alt: $0.alt, width: $0.width, height: $0.height) }
                )
            }

            Text(post.published)
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

                    if post.engagementStats.shares > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.2.squarepath")
                            Text("\(post.engagementStats.shares)")
                                .font(.caption)
                        }
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
            ComposeView(replyToPostId: post.id, replyToActor: post.actor.handle)
        }
    }
}
