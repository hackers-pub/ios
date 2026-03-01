import SwiftUI
import Kingfisher
@preconcurrency import Apollo

struct PostDetailView: View {
    private enum ActiveSheet: Identifiable {
        case reply
        case quote
        case reactors(ReactionGroupInfo)
        case shares
        case quotesList
        case reactionPicker

        var id: String {
            switch self {
            case .reply:
                return "reply"
            case .quote:
                return "quote"
            case .reactors(let reaction):
                return "reactors-\(reaction.id.uuidString)"
            case .shares:
                return "shares"
            case .quotesList:
                return "quotesList"
            case .reactionPicker:
                return "reactionPicker"
            }
        }
    }

    let postId: String
    @State private var post: HackersPub.PostDetailQuery.Data.Node.AsPost?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var activeSheet: ActiveSheet?
    @State private var refreshPostOnSheetDismiss = false
    @State private var hasMoreReplies = false
    @State private var repliesCursor: String?
    @State private var isLoadingMoreReplies = false
    @State private var isSharing = false
    @State private var isReacting = false
    @State private var showingReactionPicker = false
    @State private var hasShared = false
    @State private var sharesCount = 0
    @State private var reactionsCount = 0
    @State private var reactionSheetHeight: CGFloat = 180
    @State private var reactionGroups: [ReactionGroupSnapshot] = []
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
    @AppStorage("engagement.sharePressActionsSwapped") private var sharePressActionsSwapped = false
    @AppStorage("engagement.quotePressActionsSwapped") private var quotePressActionsSwapped = false
    @AppStorage("engagement.confirmBeforeShare") private var confirmBeforeShare = false
    @State private var showingShareConfirmation = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    private var useReactionPopover: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
    }

    private var viewerHasReacted: Bool {
        reactionGroups.contains(where: { $0.viewerHasReacted })
    }

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

                        if let quotedPost = post.quotedPost {
                            QuotedPostCard(
                                quotedPost: quotedPost,
                                disableNavigation: false,
                                showFullDateTime: true,
                                onTap: {
                                    navigationCoordinator.navigateToPost(id: quotedPost.id)
                                }
                            )
                            .padding(.horizontal)
                        }

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

                    HStack(spacing: 16) {
                        EngagementToolbarButton(
                            icon: viewerHasReacted ? "heart.fill" : "heart",
                            count: reactionsCount,
                            showsZeroCount: true,
                            tint: viewerHasReacted ? .red : .secondary,
                            isLoading: isReacting,
                            onTap: {
                                if useReactionPopover {
                                    showingReactionPicker = true
                                } else {
                                    refreshPostOnSheetDismiss = false
                                    activeSheet = .reactionPicker
                                }
                            }
                        )

                        EngagementToolbarButton(
                            icon: "arrowshape.turn.up.left",
                            count: post.engagementStats.replies,
                            showsZeroCount: true,
                            onTap: {
                                refreshPostOnSheetDismiss = true
                                activeSheet = .reply
                            }
                        )

                        EngagementToolbarButton(
                            icon: "arrow.2.squarepath",
                            count: sharesCount,
                            showsZeroCount: true,
                            tint: hasShared ? .green : .secondary,
                            isLoading: isSharing,
                            onTap: {
                                handleShareTap()
                            },
                            onLongPress: {
                                handleShareLongPress()
                            }
                        )

                        EngagementToolbarButton(
                            icon: "quote.bubble",
                            count: post.engagementStats.quotes,
                            showsZeroCount: true,
                            onTap: {
                                handleQuoteTap()
                            },
                            onLongPress: {
                                handleQuoteLongPress()
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
                    .padding(.horizontal)

                    // Reactions section
                    if !post.reactionGroups.isEmpty {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(ReactionL10n.title)
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
                                            refreshPostOnSheetDismiss = false
                                            activeSheet = .reactors(info)
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
        .sheet(item: $activeSheet, onDismiss: {
            if refreshPostOnSheetDismiss {
                refreshPostOnSheetDismiss = false
                Task {
                    await refreshPost()
                }
            }
        }) { sheet in
            switch sheet {
            case .reply:
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
            case .quote:
                if let post = post {
                    ComposeView(quotedPostId: post.id)
                }
            case .reactors(let reaction):
                ReactorsListView(reaction: reaction)
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
            case .quotesList:
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
        .confirmationDialog(
            hasShared
                ? NSLocalizedString("share.confirm.unshareTitle", comment: "Confirmation dialog title for undoing a share")
                : NSLocalizedString("share.confirm.shareTitle", comment: "Confirmation dialog title for sharing a post"),
            isPresented: $showingShareConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                hasShared
                    ? NSLocalizedString("share.confirm.unshareAction", comment: "Confirmation action to undo share")
                    : NSLocalizedString("share.confirm.shareAction", comment: "Confirmation action to share")
            ) {
                performShareToggle()
            }

            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
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
            hasShared = fetchedPost.viewerHasShared
            sharesCount = fetchedPost.engagementStats.shares
            reactionsCount = fetchedPost.engagementStats.reactions
            reactionGroups = fetchedPost.reactionGroupsSnapshot
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
            hasShared = fetchedPost.viewerHasShared
            sharesCount = fetchedPost.engagementStats.shares
            reactionsCount = fetchedPost.engagementStats.reactions
            reactionGroups = fetchedPost.reactionGroupsSnapshot
        } catch {
            errorMessage = "Failed to load post: \(error.localizedDescription)"
        }
    }

    private func fetchShares() async {
        guard !isLoadingShares else { return }

        isLoadingShares = true
        sharesErrorMessage = nil
        defer { isLoadingShares = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.PostSharesQuery(id: postId, after: nil))

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
            let response = try await apolloClient.fetch(query: HackersPub.PostSharesQuery(id: postId, after: .some(cursor)))

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
            let response = try await apolloClient.fetch(query: HackersPub.PostQuotesQuery(id: postId, after: nil))

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
            let response = try await apolloClient.fetch(query: HackersPub.PostQuotesQuery(id: postId, after: .some(cursor)))

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

    private func toggleShare() async {
        guard !isSharing else { return }
        isSharing = true
        defer { isSharing = false }

        do {
            if hasShared {
                // Unshare
                let response = try await apolloClient.perform(
                    mutation: HackersPub.UnsharePostMutation(postId: postId)
                )
                if let payload = response.data?.unsharePost.asUnsharePostPayload {
                    hasShared = payload.originalPost.viewerHasShared
                    sharesCount = payload.originalPost.engagementStats.shares
                }
            } else {
                // Share
                let response = try await apolloClient.perform(
                    mutation: HackersPub.SharePostMutation(postId: postId)
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

    private func performShareToggle() {
        guard AuthManager.shared.currentAccount != nil else { return }
        Task {
            await toggleShare()
        }
    }

    private func requestShareToggle() {
        guard AuthManager.shared.currentAccount != nil else { return }
        if confirmBeforeShare {
            showingShareConfirmation = true
        } else {
            performShareToggle()
        }
    }

    private func presentSharesSheet() {
        refreshPostOnSheetDismiss = false
        activeSheet = .shares
        Task {
            await fetchShares()
        }
    }

    private func handleShareTap() {
        if sharePressActionsSwapped {
            presentSharesSheet()
        } else {
            requestShareToggle()
        }
    }

    private func handleShareLongPress() {
        if sharePressActionsSwapped {
            requestShareToggle()
        } else {
            presentSharesSheet()
        }
    }

    private func presentQuoteComposer() {
        refreshPostOnSheetDismiss = true
        activeSheet = .quote
    }

    private func presentQuotesSheet() {
        refreshPostOnSheetDismiss = false
        activeSheet = .quotesList
        Task {
            await fetchQuotes()
        }
    }

    private func handleQuoteTap() {
        if quotePressActionsSwapped {
            presentQuotesSheet()
        } else {
            presentQuoteComposer()
        }
    }

    private func handleQuoteLongPress() {
        if quotePressActionsSwapped {
            presentQuoteComposer()
        } else {
            presentQuotesSheet()
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
                    mutation: HackersPub.RemoveReactionFromPostMutation(postId: postId, emoji: emoji)
                )

                if let payload = response.data?.removeReactionFromPost.asRemoveReactionFromPostPayload, payload.success {
                    applyReactionLocally(emoji: emoji, add: false)
                    Task { await refreshPost() }
                } else {
                    reactionErrorMessage = ReactionL10n.unableToRemove
                }
            } else {
                let response = try await apolloClient.perform(
                    mutation: HackersPub.AddReactionToPostMutation(postId: postId, emoji: emoji)
                )

                if let payload = response.data?.addReactionToPost.asAddReactionToPostPayload, payload.reaction != nil {
                    applyReactionLocally(emoji: emoji, add: true)
                    Task { await refreshPost() }
                } else {
                    reactionErrorMessage = ReactionL10n.unableToAdd
                }
            }
        } catch {
            reactionErrorMessage = shouldRemove ? ReactionL10n.unableToRemove : ReactionL10n.unableToAdd
            print("Error toggling reaction: \(error)")
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
            .navigationTitle(String(format: ReactionL10n.reactedWithFormat, reaction.emoji))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(ReactionL10n.close)
                }
            }
        }
    }
}
