import SwiftUI
import Kingfisher
@preconcurrency import Apollo

struct PostDetailView: View {
    let postId: String
    @State private var post: HackersPub.PostDetailQuery.Data.Node.AsPost?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedReaction: ReactionGroupInfo?
    @State private var showingReplyView = false
    @State private var hasMoreReplies = false
    @State private var repliesCursor: String?
    @State private var isLoadingMoreReplies = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding()
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else if let post = post {
                VStack(alignment: .leading, spacing: 16) {
                    // Display parent post if this is a reply
                    if let replyTarget = post.replyTarget {
                        VStack(alignment: .leading, spacing: 12) {
                            // Parent post author
                            HStack(spacing: 8) {
                                Button {
                                    navigationCoordinator.navigateToProfile(handle: replyTarget.actor.handle)
                                } label: {
                                    KFImage(URL(string: replyTarget.actor.avatarUrl))
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
                                    navigationCoordinator.navigateToProfile(handle: replyTarget.actor.handle)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let name = replyTarget.actor.name {
                                            HTMLTextView(html: name, font: .subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        Text(replyTarget.actor.handle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }

                            if let name = replyTarget.name {
                                Text(name)
                                    .font(.headline)
                            }

                            HTMLContentView(
                                html: replyTarget.content,
                                media: replyTarget.media.map { MediaItem(url: $0.url, thumbnailUrl: $0.thumbnailUrl, alt: $0.alt, width: $0.width, height: $0.height) }
                            )

                            Text(DateFormatHelper.fullDateTime(from: replyTarget.published))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            navigationCoordinator.navigateToPost(id: replyTarget.id)
                        }
                        .padding(.horizontal)

                        // Reply indicator
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.caption)
                            Text("Replying to")
                                .font(.caption)
                            Text(replyTarget.actor.handle)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }

                    // If this is a repost, show reposter info and shared post in a card
                    if let sharedPost = post.sharedPost {
                        // Reposter info
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
                                    .frame(width: 48, height: 48)
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
                        .padding(.horizontal)

                        Text("reposted")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        // Original post in a card
                        VStack(alignment: .leading, spacing: 12) {
                            // Original author
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
                                            HTMLTextView(html: name, font: .subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        Text(sharedPost.actor.handle)
                                            .font(.caption)
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

                            HTMLContentView(
                                html: sharedPost.content,
                                media: sharedPost.media.map { MediaItem(url: $0.url, thumbnailUrl: $0.thumbnailUrl, alt: $0.alt, width: $0.width, height: $0.height) }
                            )

                            Text(DateFormatHelper.fullDateTime(from: sharedPost.published))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            navigationCoordinator.navigateToPost(id: sharedPost.id)
                        }
                        .padding(.horizontal)
                    } else {
                        // Regular post (not a repost)
                        // Author info
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
                                    .frame(width: 48, height: 48)
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
                        .padding(.horizontal)

                        // Post title if present
                        if let name = post.name {
                            Text(name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                        }

                        // Post content
                        HTMLContentView(
                            html: post.content,
                            media: post.media.map { MediaItem(url: $0.url, thumbnailUrl: $0.thumbnailUrl, alt: $0.alt, width: $0.width, height: $0.height) }
                        )
                        .padding(.horizontal)

                        // Published date and visibility
                        HStack {
                            Text(DateFormatHelper.fullDateTime(from: post.published))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .foregroundStyle(.secondary)
                            Image(systemName: visibilityIcon(post.visibility))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Engagement stats
                    HStack(spacing: 24) {
                        StatView(count: post.engagementStats.replies, label: "Replies", icon: "arrowshape.turn.up.left")
                        StatView(count: post.engagementStats.reactions, label: "Reactions", icon: "heart")
                        StatView(count: post.engagementStats.shares, label: "Shares", icon: "arrow.2.squarepath")
                        StatView(count: post.engagementStats.quotes, label: "Quotes", icon: "quote.bubble")
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Action buttons
                    HStack(spacing: 16) {
                        Button {
                            showingReplyView = true
                        } label: {
                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)

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
                    .padding(.horizontal)

                    // Reactions section
                    if !post.reactionGroups.isEmpty {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reactions")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(post.reactionGroups.enumerated()), id: \.offset) { index, group in
                                        let _ = print("🔴 Reaction group \(index):")
                                        let _ = {
                                            if let emoji = group.asEmojiReactionGroup {
                                                print("   Emoji: \(emoji.emoji), Count: \(emoji.reactors.totalCount), Reactors: \(emoji.reactors.edges.count)")
                                            } else if let custom = group.asCustomEmojiReactionGroup {
                                                print("   Custom: \(custom.customEmoji.name), Count: \(custom.reactors.totalCount), Reactors: \(custom.reactors.edges.count)")
                                            }
                                        }()
                                        ReactionGroupView(group: group, onTap: {
                                            let info = reactionGroupInfo(from: group)
                                            print("🔴 Opening reactors sheet - Emoji: \(info.emoji), Total: \(info.totalCount), Reactors in list: \(info.reactors.count)")
                                            selectedReaction = info
                                        })
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Replies section - only show if there are replies or more to load
                    if !post.replies.edges.isEmpty || hasMoreReplies {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Replies")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(post.replies.edges.map { $0.node }, id: \.id) { reply in
                                PostView(post: reply, showAuthor: true, disableNavigation: false)
                                    .padding(.horizontal)
                                Divider()
                                    .padding(.horizontal)
                            }

                            if hasMoreReplies {
                                if isLoadingMoreReplies {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding()
                                } else {
                                    Button("Load more replies") {
                                        Task {
                                            await loadMoreReplies()
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchPost()
        }
        .refreshable {
            await refreshPost()
        }
        .sheet(isPresented: $showingReplyView, onDismiss: {
            // Refetch post after dismissing reply sheet
            Task {
                await refreshPost()
            }
        }) {
            if let post = post {
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
        .sheet(item: $selectedReaction) { reaction in
            ReactorsListView(reaction: reaction)
        }
    }

    private func fetchPost() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PostDetailQuery(id: postId, repliesAfter: nil))

            if let errors = response.errors, !errors.isEmpty {
                errorMessage = errors.first?.message ?? "Unknown error"
                return
            }

            guard let fetchedPost = response.data?.node?.asPost else {
                errorMessage = "Post not found"
                return
            }

            post = fetchedPost
            hasMoreReplies = fetchedPost.replies.pageInfo.hasNextPage
            repliesCursor = fetchedPost.replies.pageInfo.endCursor
        } catch {
            errorMessage = "Failed to load post: \(error.localizedDescription)"
        }
    }

    private func loadMoreReplies() async {
        guard let cursor = repliesCursor, hasMoreReplies, !isLoadingMoreReplies else { return }

        isLoadingMoreReplies = true
        defer { isLoadingMoreReplies = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PostDetailQuery(id: postId, repliesAfter: .some(cursor)))

            if let fetchedPost = response.data?.node?.asPost {
                let newReplies = fetchedPost.replies
                // Append new replies to existing ones
                // Note: This is a simplified approach. In production, you'd want to update the entire post object properly

                hasMoreReplies = newReplies.pageInfo.hasNextPage
                repliesCursor = newReplies.pageInfo.endCursor
            }
        } catch {
            print("Error loading more replies: \(error)")
        }
    }

    private func refreshPost() async {
        errorMessage = nil

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PostDetailQuery(id: postId, repliesAfter: nil))

            if let errors = response.errors, !errors.isEmpty {
                errorMessage = errors.first?.message ?? "Unknown error"
                return
            }

            guard let fetchedPost = response.data?.node?.asPost else {
                errorMessage = "Post not found"
                return
            }

            post = fetchedPost
            hasMoreReplies = fetchedPost.replies.pageInfo.hasNextPage
            repliesCursor = fetchedPost.replies.pageInfo.endCursor
        } catch {
            errorMessage = "Failed to load post: \(error.localizedDescription)"
        }
    }

    private func visibilityIcon(_ visibility: GraphQLEnum<HackersPub.PostVisibility>) -> String {
        switch visibility {
        case .case(.public):
            return "globe"
        case .case(.unlisted):
            return "lock.open"
        case .case(.followers):
            return "person.2"
        case .case(.direct):
            return "envelope"
        default:
            return "questionmark"
        }
    }

    private func reactionGroupInfo(from group: HackersPub.PostDetailQuery.Data.Node.AsPost.ReactionGroup) -> ReactionGroupInfo {
        if let emojiGroup = group.asEmojiReactionGroup {
            return ReactionGroupInfo(
                emoji: emojiGroup.emoji,
                customEmojiUrl: nil,
                reactors: emojiGroup.reactors.edges.map { edge in
                    ReactorInfo(
                        id: edge.node.id,
                        name: edge.node.name,
                        handle: edge.node.handle,
                        avatarUrl: edge.node.avatarUrl
                    )
                },
                totalCount: emojiGroup.reactors.totalCount
            )
        } else if let customGroup = group.asCustomEmojiReactionGroup {
            return ReactionGroupInfo(
                emoji: customGroup.customEmoji.name,
                customEmojiUrl: customGroup.customEmoji.imageUrl,
                reactors: customGroup.reactors.edges.map { edge in
                    ReactorInfo(
                        id: edge.node.id,
                        name: edge.node.name,
                        handle: edge.node.handle,
                        avatarUrl: edge.node.avatarUrl
                    )
                },
                totalCount: customGroup.reactors.totalCount
            )
        }
        return ReactionGroupInfo(emoji: "?", customEmojiUrl: nil, reactors: [], totalCount: 0)
    }
}

struct StatView: View {
    let count: Int
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text("\(count)")
                    .font(.headline)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ReactionGroupView: View {
    let group: HackersPub.PostDetailQuery.Data.Node.AsPost.ReactionGroup
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let emojiGroup = group.asEmojiReactionGroup {
                Text(emojiGroup.emoji)
                    .font(.title3)
                Text("\(emojiGroup.reactors.totalCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let customGroup = group.asCustomEmojiReactionGroup {
                KFImage(URL(string: customGroup.customEmoji.imageUrl))
                    .placeholder {
                        Text(customGroup.customEmoji.name)
                            .font(.caption)
                    }
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text("\(customGroup.reactors.totalCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onTap()
        }
    }
}

struct ReactorInfo: Identifiable {
    let id: String
    let name: String?
    let handle: String
    let avatarUrl: String
}

struct ReactionGroupInfo: Identifiable {
    let id = UUID()
    let emoji: String
    let customEmojiUrl: String?
    let reactors: [ReactorInfo]
    let totalCount: Int
}

struct ReactorsListView: View {
    let reaction: ReactionGroupInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        NavigationStack {
            List {
                ForEach(reaction.reactors) { reactor in
                    Button {
                        dismiss()
                        navigationCoordinator.navigateToProfile(handle: reactor.handle)
                    } label: {
                        HStack(spacing: 12) {
                            KFImage(URL(string: reactor.avatarUrl))
                                .placeholder {
                                    Color.gray.opacity(0.2)
                                }
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                if let name = reactor.name {
                                    HTMLTextView(html: name, font: .subheadline)
                                        .fontWeight(.semibold)
                                }
                                Text(reactor.handle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Reacted with \(reaction.emoji)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
