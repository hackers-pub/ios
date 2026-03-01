@preconcurrency import Apollo
import Kingfisher
import SwiftUI

protocol EngagementStatsProtocol {
    var replies: Int { get }
    var reactions: Int { get }
    var shares: Int { get }
    var quotes: Int { get }
}

protocol QuotedPostProtocol {
    associatedtype ActorType: ActorProtocol
    associatedtype MediaType: MediaProtocol

    var id: String { get }
    var name: String? { get }
    var published: String { get }
    var content: String { get }
    var actor: ActorType { get }
    var media: [MediaType] { get }
}

protocol PostProtocol: QuotedPostProtocol {
    associatedtype SharedPostType: PostProtocol
    associatedtype QuotedPostType: QuotedPostProtocol
    associatedtype EngagementStatsType: EngagementStatsProtocol

    var summary: String? { get }
    var excerpt: String { get }
    var url: String? { get }
    var sharedPost: SharedPostType? { get }
    var quotedPost: QuotedPostType? { get }
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

struct EngagementToolbarButton: View {
    let icon: String
    let count: Int
    let showsZeroCount: Bool
    let tint: Color
    let isLoading: Bool
    let onTap: () -> Void
    let onLongPress: (() -> Void)?

    @State private var suppressTap = false

    init(
        icon: String,
        count: Int,
        showsZeroCount: Bool,
        tint: Color = .secondary,
        isLoading: Bool = false,
        onTap: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.count = count
        self.showsZeroCount = showsZeroCount
        self.tint = tint
        self.isLoading = isLoading
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }

            if showsZeroCount || count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(tint)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            if suppressTap {
                suppressTap = false
                return
            }
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            guard let onLongPress else { return }
            suppressTap = true
            onLongPress()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                suppressTap = false
            }
        }
    }
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
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(actor.handle)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .buttonStyle(.plain)

            Text("reposted")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

struct QuotedPostCard<QuotedPost: QuotedPostProtocol>: View {
    let quotedPost: QuotedPost
    let disableNavigation: Bool
    let showFullDateTime: Bool
    let onTap: (() -> Void)?

    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(
        quotedPost: QuotedPost,
        disableNavigation: Bool = false,
        showFullDateTime: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.quotedPost = quotedPost
        self.disableNavigation = disableNavigation
        self.showFullDateTime = showFullDateTime
        self.onTap = onTap
    }

    private var publishedText: String {
        if showFullDateTime {
            return DateFormatHelper.fullDateTime(from: quotedPost.published)
        }
        return DateFormatHelper.relativeTime(from: quotedPost.published)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    navigationCoordinator.navigateToProfile(handle: quotedPost.actor.handle)
                } label: {
                    KFImage(URL(string: quotedPost.actor.avatarUrl))
                        .placeholder {
                            Color.gray.opacity(0.2)
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    navigationCoordinator.navigateToProfile(handle: quotedPost.actor.handle)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = quotedPost.actor.name {
                            HTMLTextView(html: name, font: .subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Text(quotedPost.actor.handle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if let name = quotedPost.name {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            HTMLContentView(
                html: quotedPost.content,
                media: quotedPost.media.map {
                    MediaItem(
                        url: $0.url,
                        thumbnailUrl: $0.thumbnailUrl,
                        alt: $0.alt,
                        width: $0.width,
                        height: $0.height
                    )
                },
                onTap: !disableNavigation ? onTap : nil
            )

            Text(publishedText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            guard !disableNavigation else { return }
            onTap?()
        }
    }
}

struct PostView<P: PostProtocol & ReactionCapablePostProtocol>: View {
    private enum ActiveSheet: Identifiable {
        case reply
        case quote
        case shares
        case quotes
        case reactionPicker

        var id: String {
            switch self {
            case .reply:
                return "reply"
            case .quote:
                return "quote"
            case .shares:
                return "shares"
            case .quotes:
                return "quotes"
            case .reactionPicker:
                return "reactionPicker"
            }
        }
    }

    let post: P
    let showAuthor: Bool
    let disableNavigation: Bool
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var activeSheet: ActiveSheet?
    @State private var showingReactionPicker = false
    @State private var isSharing = false
    @State private var isReacting = false
    @State private var hasShared: Bool
    @State private var sharesCount: Int
    @State private var reactionsCount: Int
    @State private var reactionSheetHeight: CGFloat = 180
    @State private var reactionGroups: [ReactionGroupSnapshot]
    @State private var reactionErrorMessage: String?
    @State private var shareActors: [ShareActorInfo] = []
    @State private var isLoadingShares = false
    @State private var sharesErrorMessage: String?
    @State private var hasMoreShares = false
    @State private var sharesCursor: String?
    @State private var isLoadingMoreShares = false
    @State private var quotes: [HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node] = []
    @State private var isLoadingQuotes = false
    @State private var quotesErrorMessage: String?
    @State private var hasMoreQuotes = false
    @State private var quotesCursor: String?
    @State private var isLoadingMoreQuotes = false
    @State private var markdownMaxLength = UserDefaults.standard.integer(forKey: "markdownMaxLength") {
        didSet {
            UserDefaults.standard.set(markdownMaxLength, forKey: "markdownMaxLength")
        }
    }

    init(post: P, showAuthor: Bool = true, disableNavigation: Bool = false) {
        self.post = post
        self.showAuthor = showAuthor
        self.disableNavigation = disableNavigation
        _hasShared = State(initialValue: post.viewerHasShared)
        _sharesCount = State(initialValue: post.engagementStats.shares)
        _reactionsCount = State(initialValue: post.engagementStats.reactions)
        _reactionGroups = State(initialValue: post.reactionGroupsSnapshot)
    }

    private var useReactionPopover: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
    }

    private var viewerHasReacted: Bool {
        reactionGroups.contains(where: { $0.viewerHasReacted })
    }

    private func getContent(content: String) -> String {
        if markdownMaxLength != 0 {
            let options = HTMLTruncateOptions(
                readMoreText: String(
                    localized: "truncate.readMore",
                    defaultValue: "Read more"
                )
            )
            return content.htmlTruncated(limit: markdownMaxLength, options: options)
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

    private func applyReactionLocally(emoji: String, add: Bool) {
        if let existingIndex = reactionGroups.firstIndex(where: { $0.emoji == emoji }) {
            var group = reactionGroups[existingIndex]
            let updatedCount = max(0, group.totalCount + (add ? 1 : -1))
            if updatedCount == 0 {
                reactionGroups.remove(at: existingIndex)
            } else {
                group.totalCount = updatedCount
                group.viewerHasReacted = add
                reactionGroups[existingIndex] = group
            }
        } else if add {
            reactionGroups.append(
                ReactionGroupSnapshot(
                    id: "emoji:\(emoji)",
                    emoji: emoji,
                    customEmojiName: nil,
                    customEmojiImageUrl: nil,
                    totalCount: 1,
                    viewerHasReacted: true
                )
            )
        }
        reactionsCount = max(0, reactionsCount + (add ? 1 : -1))
    }

    private func toggleReaction(emoji: String) async {
        guard !isReacting else { return }
        guard AuthManager.shared.currentAccount != nil else {
            reactionErrorMessage = ReactionL10n.signInRequired
            return
        }
        isReacting = true
        defer { isReacting = false }

        let shouldRemove = reactionGroups.first(where: { $0.emoji == emoji })?.viewerHasReacted == true

        do {
            if shouldRemove {
                let response = try await apolloClient.perform(
                    mutation: HackersPub.RemoveReactionFromPostMutation(postId: post.id, emoji: emoji)
                )

                if let payload = response.data?.removeReactionFromPost.asRemoveReactionFromPostPayload, payload.success {
                    applyReactionLocally(emoji: emoji, add: false)
                } else {
                    reactionErrorMessage = ReactionL10n.unableToRemove
                }
            } else {
                let response = try await apolloClient.perform(
                    mutation: HackersPub.AddReactionToPostMutation(postId: post.id, emoji: emoji)
                )

                if let payload = response.data?.addReactionToPost.asAddReactionToPostPayload, payload.reaction != nil {
                    applyReactionLocally(emoji: emoji, add: true)
                } else {
                    reactionErrorMessage = ReactionL10n.unableToAdd
                }
            }
        } catch {
            reactionErrorMessage = shouldRemove ? ReactionL10n.unableToRemove : ReactionL10n.unableToAdd
            print("Error toggling reaction: \(error)")
        }
    }

    private func fetchShares() async {
        guard !isLoadingShares else { return }

        isLoadingShares = true
        sharesErrorMessage = nil
        defer { isLoadingShares = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PostSharesQuery(id: post.id, after: nil))

            if let errors = response.errors, !errors.isEmpty {
                sharesErrorMessage = errors.first?.message ?? "Unknown error"
                return
            }

            guard let shares = response.data?.node?.asPost?.shares else {
                shareActors = []
                hasMoreShares = false
                sharesCursor = nil
                return
            }

            shareActors = shares.edges.map { edge in
                ShareActorInfo(
                    id: edge.node.actor.id,
                    name: edge.node.actor.name,
                    handle: edge.node.actor.handle,
                    avatarUrl: edge.node.actor.avatarUrl
                )
            }
            hasMoreShares = shares.pageInfo.hasNextPage
            sharesCursor = shares.pageInfo.endCursor
        } catch {
            sharesErrorMessage = "Failed to load shares: \(error.localizedDescription)"
        }
    }

    private func loadMoreShares() async {
        guard let cursor = sharesCursor, hasMoreShares, !isLoadingMoreShares else { return }

        isLoadingMoreShares = true
        defer { isLoadingMoreShares = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PostSharesQuery(id: post.id, after: .some(cursor)))

            if let errors = response.errors, !errors.isEmpty {
                sharesErrorMessage = errors.first?.message ?? "Unknown error"
                return
            }

            guard let shares = response.data?.node?.asPost?.shares else {
                return
            }

            let incoming = shares.edges.map { edge in
                ShareActorInfo(
                    id: edge.node.actor.id,
                    name: edge.node.actor.name,
                    handle: edge.node.actor.handle,
                    avatarUrl: edge.node.actor.avatarUrl
                )
            }
            for actor in incoming where !shareActors.contains(where: { $0.id == actor.id }) {
                shareActors.append(actor)
            }

            hasMoreShares = shares.pageInfo.hasNextPage
            sharesCursor = shares.pageInfo.endCursor
        } catch {
            sharesErrorMessage = "Failed to load more shares: \(error.localizedDescription)"
        }
    }

    private func fetchQuotes() async {
        guard !isLoadingQuotes else { return }

        isLoadingQuotes = true
        quotesErrorMessage = nil
        defer { isLoadingQuotes = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PostQuotesQuery(id: post.id, after: nil))

            if let errors = response.errors, !errors.isEmpty {
                quotesErrorMessage = errors.first?.message ?? "Unknown error"
                return
            }

            guard let quotesConnection = response.data?.node?.asPost?.quotes else {
                quotes = []
                hasMoreQuotes = false
                quotesCursor = nil
                return
            }

            quotes = quotesConnection.edges.map { $0.node }
            hasMoreQuotes = quotesConnection.pageInfo.hasNextPage
            quotesCursor = quotesConnection.pageInfo.endCursor
        } catch {
            quotesErrorMessage = "Failed to load quotes: \(error.localizedDescription)"
        }
    }

    private func loadMoreQuotes() async {
        guard let cursor = quotesCursor, hasMoreQuotes, !isLoadingMoreQuotes else { return }

        isLoadingMoreQuotes = true
        defer { isLoadingMoreQuotes = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PostQuotesQuery(id: post.id, after: .some(cursor)))

            if let errors = response.errors, !errors.isEmpty {
                quotesErrorMessage = errors.first?.message ?? "Unknown error"
                return
            }

            guard let quotesConnection = response.data?.node?.asPost?.quotes else {
                return
            }

            quotes.append(contentsOf: quotesConnection.edges.map { $0.node })
            hasMoreQuotes = quotesConnection.pageInfo.hasNextPage
            quotesCursor = quotesConnection.pageInfo.endCursor
        } catch {
            quotesErrorMessage = "Failed to load more quotes: \(error.localizedDescription)"
        }
    }

    private func openQuotedPost(id: String) {
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            navigationCoordinator.navigateToPost(id: id)
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
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                Text(post.actor.handle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 8)
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
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                    Text(sharedPost.actor.handle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 8)
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }

                        if let name = sharedPost.name {
                            Text(name)
                                .font(.headline)
                        }

                        let content = self.getContent(content: sharedPost.content)
                        HTMLContentView(
                            html: content,
                            media: sharedPost.media.map {
                                MediaItem(
                                    url: $0.url, thumbnailUrl: $0.thumbnailUrl,
                                    alt: $0.alt, width: $0.width, height: $0.height
                                )
                            },
                            onTap: !disableNavigation ? {
                                navigationCoordinator.navigateToPost(id: sharedPost.id)
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
                        media: post.media.map {
                            MediaItem(
                                url: $0.url, thumbnailUrl: $0.thumbnailUrl,
                                alt: $0.alt, width: $0.width, height: $0.height
                            )
                        },
                        onTap: !disableNavigation && !post.isArticle ? {
                            navigationCoordinator.navigateToPost(id: post.id)
                        } : nil
                    )

                    if let quotedPost = post.quotedPost {
                        QuotedPostCard(
                            quotedPost: quotedPost,
                            disableNavigation: disableNavigation,
                            onTap: {
                                navigationCoordinator.navigateToPost(id: quotedPost.id)
                            }
                        )
                    }
                }

                Text(DateFormatHelper.relativeTime(from: post.published))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    EngagementToolbarButton(
                        icon: viewerHasReacted ? "heart.fill" : "heart",
                        count: reactionsCount,
                        showsZeroCount: false,
                        tint: viewerHasReacted ? .red : .secondary,
                        isLoading: isReacting,
                        onTap: {
                            if useReactionPopover {
                                showingReactionPicker = true
                            } else {
                                activeSheet = .reactionPicker
                            }
                        }
                    )

                    EngagementToolbarButton(
                        icon: "arrowshape.turn.up.left",
                        count: post.engagementStats.replies,
                        showsZeroCount: false,
                        onTap: {
                            activeSheet = .reply
                        }
                    )

                    EngagementToolbarButton(
                        icon: "arrow.2.squarepath",
                        count: sharesCount,
                        showsZeroCount: false,
                        tint: hasShared ? .green : .secondary,
                        isLoading: isSharing,
                        onTap: {
                            guard AuthManager.shared.currentAccount != nil else { return }
                            Task {
                                await toggleShare()
                            }
                        },
                        onLongPress: {
                            activeSheet = .shares
                            Task {
                                await fetchShares()
                            }
                        }
                    )

                    EngagementToolbarButton(
                        icon: "quote.bubble",
                        count: post.engagementStats.quotes,
                        showsZeroCount: false,
                        onTap: {
                            activeSheet = .quote
                        },
                        onLongPress: {
                            activeSheet = .quotes
                            Task {
                                await fetchQuotes()
                            }
                        }
                    )

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
        .onChange(of: post.id) {
            hasShared = post.viewerHasShared
            sharesCount = post.engagementStats.shares
            reactionsCount = post.engagementStats.reactions
            reactionGroups = post.reactionGroupsSnapshot
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .reply:
                ComposeView(
                    replyToPostId: post.id,
                    replyToActor: post.actor.handle,
                    initialMentions: getMentionHandles(
                        from: post,
                        excludingHandle: AuthManager.shared.currentAccount?.handle
                    )
                )
            case .quote:
                ComposeView(quotedPostId: post.id)
            case .shares:
                SharesListSheetView(
                    title: "Shares",
                    actors: shareActors,
                    isLoading: isLoadingShares,
                    isLoadingMore: isLoadingMoreShares,
                    errorMessage: sharesErrorMessage,
                    emptyTitle: "No shares yet",
                    hasMore: hasMoreShares,
                    loadMoreTitle: "Load more shares",
                    onRetry: {
                        Task {
                            await fetchShares()
                        }
                    },
                    onLoadMore: {
                        Task {
                            await loadMoreShares()
                        }
                    }
                )
            case .quotes:
                NavigationStack {
                    QuotesListSheetView(
                        items: quotes,
                        isLoading: isLoadingQuotes,
                        errorMessage: quotesErrorMessage,
                        emptyTitle: "No quotes yet",
                        hasMore: hasMoreQuotes,
                        isLoadingMore: isLoadingMoreQuotes,
                        loadMoreTitle: "Load more quotes",
                        onRetry: {
                            Task {
                                await fetchQuotes()
                            }
                        },
                        onLoadMore: {
                            Task {
                                await loadMoreQuotes()
                            }
                        },
                        onPostSelected: { selectedId in
                            openQuotedPost(id: selectedId)
                        }
                    )
                    .navigationTitle("Quotes")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                activeSheet = nil
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel(NSLocalizedString("reaction.action.close", comment: "Close"))
                        }
                    }
                }
            case .reactionPicker:
                ReactionPickerView(
                    reactionGroups: reactionGroups,
                    isSubmitting: isReacting,
                    onEmojiSelect: { emoji in
                        Task {
                            await toggleReaction(emoji: emoji)
                        }
                    },
                    onClose: {
                        activeSheet = nil
                    }
                )
                .trackReactionPickerHeight { contentHeight in
                    let targetHeight = min(max(contentHeight + 24, 160), 340)
                    if abs(reactionSheetHeight - targetHeight) > 1 {
                        reactionSheetHeight = targetHeight
                    }
                }
                .presentationDetents([.height(reactionSheetHeight)])
            }
        }
        .popover(
            isPresented: Binding(
                get: { showingReactionPicker && useReactionPopover },
                set: { isPresented in
                    if !isPresented {
                        showingReactionPicker = false
                    }
                }
            ),
            arrowEdge: .bottom
        ) {
            ReactionPickerView(
                reactionGroups: reactionGroups,
                isSubmitting: isReacting,
                onEmojiSelect: { emoji in
                    Task {
                        await toggleReaction(emoji: emoji)
                    }
                },
                onClose: {
                    showingReactionPicker = false
                }
            )
            .frame(width: 360)
        }
        .alert(
            ReactionL10n.failedTitle,
            isPresented: Binding(
                get: { reactionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        reactionErrorMessage = nil
                    }
                }
            )
        ) {
            Button(NSLocalizedString("compose.error.ok", comment: "OK button"), role: .cancel) {
                reactionErrorMessage = nil
            }
        } message: {
            Text(reactionErrorMessage ?? "")
        }
    }
}
