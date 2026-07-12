@preconcurrency import Apollo
import Kingfisher
import SwiftUI

struct PostDetailQuotePresentation: QuotedPostProtocol, Equatable {
    struct Actor: ActorProtocol, Equatable {
        let id: String
        let name: String?
        let handle: String
        let avatarUrl: String
    }

    struct Medium: MediaProtocol, Equatable {
        let url: String
        let thumbnailUrl: String?
        let alt: String?
        let width: Int?
        let height: Int?
    }

    let id: String
    let navigationPostID: String
    let name: String?
    let published: String
    let content: String
    let actor: Actor
    let media: [Medium]

    init?<SharedPost: PostProtocol>(sharedPost: SharedPost) {
        guard let quotedPost = sharedPost.quotedPost else { return nil }

        id = quotedPost.id
        navigationPostID = quotedPost.id
        name = quotedPost.name
        published = quotedPost.published
        content = quotedPost.content
        actor = Actor(
            id: quotedPost.actor.id,
            name: quotedPost.actor.name,
            handle: quotedPost.actor.handle,
            avatarUrl: quotedPost.actor.avatarUrl
        )
        media = quotedPost.media.map {
            Medium(
                url: $0.url,
                thumbnailUrl: $0.thumbnailUrl,
                alt: $0.alt,
                width: $0.width,
                height: $0.height
            )
        }
    }
}

struct PostDetailView: View {
    private enum ScrollAnchor: Hashable {
        case replies
    }

    private enum ActiveSheet: Identifiable {
        case reply
        case quote
        case reactors(ReactionGroupInfo)
        case shares
        case quotesList
        case reactionPicker
        case editArticle

        var id: String {
            switch self {
            case .reply:
                return "reply"
            case .quote:
                return "quote"
            case let .reactors(reaction):
                return "reactors-\(reaction.id)"
            case .shares:
                return "shares"
            case .quotesList:
                return "quotesList"
            case .reactionPicker:
                return "reactionPicker"
            case .editArticle:
                return "editArticle"
            }
        }
    }

    let postId: String
    let onBookmarkChanged: ((String, Bool) -> Void)?

    init(
        postId: String,
        onBookmarkChanged: ((String, Bool) -> Void)? = nil
    ) {
        self.postId = postId
        self.onBookmarkChanged = onBookmarkChanged
        _sharesState = State(initialValue: Self.makeSharesState(postID: postId))
        _quotesState = State(initialValue: Self.makeQuotesState(postID: postId))
    }

    @Environment(\.dismiss) private var dismiss
    @State private var post: HackersPub.PostDetailQuery.Data.Node.AsPost?
    @State private var isLoading = true
    @State private var failureState = PostDetailFailureState()
    @State private var activeSheet: ActiveSheet?
    @State private var pendingQuotedPostNavigation = PendingSheetPostNavigation()
    @State private var refreshPostOnSheetDismiss = false
    @State private var hasMoreReplies = false
    @State private var repliesCursor: String?
    @State private var replyEdges: [HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge] = []
    @State private var isLoadingMoreReplies = false
    @State private var isBookmarking = false
    @State private var isReacting = false
    @State private var showingReactionPicker = false
    @State private var engagementState: PostEngagementState?
    @State private var reactionInfoState = ReactionInfoLoadState<ReactionGroupInfo>()
    @State private var reactionRetryEmoji: String?
    @State private var reactionCoordinator: PostReactionRequestCoordinator?
    @State private var sharesState: EngagementListSheetState<ShareActorInfo>
    @State private var quotesState: EngagementListSheetState<PostEngagementSheetLoader.Quote>
    @AppStorage("engagement.sharePressActionsSwapped") private var sharePressActionsSwapped = false
    @AppStorage("engagement.quotePressActionsSwapped") private var quotePressActionsSwapped = false
    @AppStorage("engagement.confirmBeforeShare") private var confirmBeforeShare = false
    @AppStorage("engagement.confirmBeforeDelete") private var confirmBeforeDelete = true
    @State private var showingShareConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    @State private var articleContents: [HackersPub.PostDetailQuery.Data.Node.AsArticle.Content] = []
    @State private var translatedArticleContent: HackersPub.ArticleTranslationQuery.Data.Node.AsArticle.Content?
    @State private var isLoadingArticleTranslation = false
    @State private var showingOriginalArticle = true
    @State private var translatedArticleLanguage: String?
    @State private var translationRetryLanguage: String?
    @State private var articleTags: [String] = []
    @State private var articleLanguage: String?
    @State private var articleAllowLlmTranslation = true
    @State private var articleSourceId: String?
    @Environment(AuthManager.self) private var authManager
    @Environment(ExternalURLRouter.self) private var externalURLRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    private static func makeSharesState(postID: String) -> EngagementListSheetState<ShareActorInfo> {
        makeSharesState(sharesLoader(for: postID))
    }

    static func makeSharesState(
        _ loader: @escaping EngagementListSheetState<ShareActorInfo>.Loader
    ) -> EngagementListSheetState<ShareActorInfo> {
        EngagementListSheetState(id: \.id, loader: loader)
    }

    private static func sharesLoader(
        for postID: String
    ) -> EngagementListSheetState<ShareActorInfo>.Loader {
        { cursor in
            await PostEngagementSheetLoader.shares(postID: postID, after: cursor)
        }
    }

    private static func makeQuotesState(
        postID: String
    ) -> EngagementListSheetState<PostEngagementSheetLoader.Quote> {
        EngagementListSheetState(id: \.id, loader: quotesLoader(for: postID))
    }

    private static func quotesLoader(
        for postID: String
    ) -> EngagementListSheetState<PostEngagementSheetLoader.Quote>.Loader {
        { cursor in
            await PostEngagementSheetLoader.quotes(postID: postID, after: cursor)
        }
    }

    private var useReactionPopover: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
    }

    private var viewerHasReacted: Bool {
        engagementState?.viewerHasReacted == true
    }

    private var engagementTargetID: String {
        engagementState?.target.postID ?? postId
    }

    private func canDelete(post: HackersPub.PostDetailQuery.Data.Node.AsPost) -> Bool {
        guard let viewerHandle = authManager.currentAccount?.handle else { return false }
        let isViewerAuthor = viewerHandle.caseInsensitiveCompare(post.actor.handle) == .orderedSame
        return isViewerAuthor && post.sharedPost == nil
    }

    private var canEditArticle: Bool {
        guard let post, articleSourceId != nil else { return false }
        return canDelete(post: post)
    }

    private var canPerformEngagementActions: Bool {
        authManager.isAuthenticated
    }

    private var selectedArticleContentHTML: String? {
        if !showingOriginalArticle, let translatedArticleContent {
            return translatedArticleContent.content
        }
        return nil
    }

    private var selectedArticleTOC: [ArticleTOCItem] {
        guard showingOriginalArticle else { return [] }
        let rawTOC = matchingOriginalArticleContent?.toc ?? articleContents.first?.toc
        return rawTOC.map(ArticleTOCParser.parse) ?? []
    }

    private var selectedArticleTitle: String? {
        if !showingOriginalArticle, let translatedArticleContent {
            return translatedArticleContent.title
        }
        return nil
    }

    private var originalArticleRawContent: String? {
        matchingOriginalArticleContent?.rawContent ?? articleContents.first?.rawContent
    }

    private func normalizeLanguageIdentifier(_ language: String) -> String {
        language
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }

    private var articleTranslationLanguageOptions: [String] {
        var options = Locale.preferredLanguages.map(normalizeLanguageIdentifier)
        if let currentLanguageCode = Locale.current.language.languageCode?.identifier {
            options.append(normalizeLanguageIdentifier(currentLanguageCode))
        }
        options.append("en")

        var seen: Set<String> = []
        return options.compactMap { language in
            let baseLanguage = String(language.split(separator: "-").first ?? Substring(language))
            guard !baseLanguage.isEmpty, seen.insert(baseLanguage).inserted else { return nil }
            return baseLanguage
        }
    }

    private func localizedLanguageName(for language: String) -> String {
        Locale.current.localizedString(forIdentifier: language) ?? language
    }

    private var matchingOriginalArticleContent: HackersPub.PostDetailQuery.Data.Node.AsArticle.Content? {
        guard let post else { return articleContents.first }

        if let exactContentMatch = articleContents.first(where: { $0.content == post.content }) {
            return exactContentMatch
        }

        if let postName = post.name, let titleMatch = articleContents.first(where: { $0.title == postName }) {
            return titleMatch
        }

        return articleContents.first
    }

    private func reconcileEngagementState(
        with fetchedPost: HackersPub.PostDetailQuery.Data.Node.AsPost
    ) {
        let incomingState = PostEngagementState(post: fetchedPost)
        let targetChanged = engagementState?.target.postID != incomingState.target.postID
        engagementState = incomingState

        if targetChanged {
            sharesState.reset(loader: Self.sharesLoader(for: incomingState.target.postID))
            quotesState.reset(loader: Self.quotesLoader(for: incomingState.target.postID))
            reactionInfoState = ReactionInfoLoadState()
            reactionRetryEmoji = nil
            reactionCoordinator = PostReactionRequestCoordinator(targetPostID: incomingState.target.postID)
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                if isLoading && post == nil {
                    ProgressView()
                        .padding()
                } else if post == nil, let error = failureState.blockingMessage {
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

                                EmbeddedPostContentPreviewView(
                                    html: replyTarget.content,
                                    media: replyTarget.media.map { medium in
                                        MediaItem(
                                            url: medium.url,
                                            thumbnailUrl: medium.thumbnailUrl,
                                            alt: medium.alt,
                                            width: medium.width,
                                            height: medium.height
                                        )
                                    }
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
                                Text(PostL10n.replyingTo)
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

                            Text(PostL10n.reposted)
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

                                EmbeddedPostContentPreviewView(
                                    html: sharedPost.content,
                                    media: sharedPost.media.map { medium in
                                        MediaItem(
                                            url: medium.url,
                                            thumbnailUrl: medium.thumbnailUrl,
                                            alt: medium.alt,
                                            width: medium.width,
                                            height: medium.height
                                        )
                                    }
                                )

                                if let quotedPost = PostDetailQuotePresentation(sharedPost: sharedPost) {
                                    QuotedPostCard(
                                        quotedPost: quotedPost,
                                        disableNavigation: false,
                                        showFullDateTime: true,
                                        onTap: {
                                            navigationCoordinator.navigateToPost(id: quotedPost.navigationPostID)
                                        }
                                    )
                                }

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
                            if let title = post.isArticle ? selectedArticleTitle ?? post.name : post.name {
                                Text(title)
                                    .font(post.isArticle ? .largeTitle : .title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                            }

                            if post.isArticle {
                                ArticleContentPane(
                                    html: selectedArticleContentHTML ?? post.content,
                                    toc: selectedArticleTOC,
                                    media: post.media.map { medium in
                                        MediaItem(
                                            url: medium.url,
                                            thumbnailUrl: medium.thumbnailUrl,
                                            alt: medium.alt,
                                            width: medium.width,
                                            height: medium.height
                                        )
                                    },
                                    onAnchorSelected: { anchorID in
                                        withAnimation(.easeInOut) {
                                            scrollProxy.scrollTo(anchorID, anchor: .top)
                                        }
                                    }
                                )
                                .padding(.horizontal)

                                HStack(spacing: 12) {
                                    if isLoadingArticleTranslation {
                                        ProgressView()
                                    } else if showingOriginalArticle {
                                        Menu {
                                            ForEach(articleTranslationLanguageOptions, id: \.self) { language in
                                                Button {
                                                    Task {
                                                        await loadArticleTranslation(postId: post.id, language: language)
                                                    }
                                                } label: {
                                                    Text(localizedLanguageName(for: language))
                                                }
                                            }
                                        } label: {
                                            Label(
                                                NSLocalizedString(
                                                    "article.translate",
                                                    comment: "Translate article"
                                                ),
                                                systemImage: "translate"
                                            )
                                        }
                                    } else {
                                        Button {
                                            showingOriginalArticle = true
                                        } label: {
                                            Label(
                                                NSLocalizedString(
                                                    "article.showOriginal",
                                                    comment: "Show original article"
                                                ),
                                                systemImage: "doc.text"
                                            )
                                        }
                                    }

                                    if let url = post.resolvedShareURL {
                                        Button {
                                            externalURLRouter.open(url)
                                        } label: {
                                            Label(
                                                NSLocalizedString(
                                                    "article.readOnWeb",
                                                    comment: "Read on web"
                                                ),
                                                systemImage: "safari"
                                            )
                                        }
                                    }

                                    if canEditArticle {
                                        Button {
                                            activeSheet = .editArticle
                                        } label: {
                                            Label(NSLocalizedString("article.edit", comment: "Edit article"), systemImage: "pencil")
                                        }
                                    }
                                }
                                .font(.caption)
                                .padding(.horizontal)
                            } else {
                                // Post content
                                PostContentDetailView(
                                    html: post.content,
                                    media: post.media.map { medium in
                                        MediaItem(
                                            url: medium.url,
                                            thumbnailUrl: medium.thumbnailUrl,
                                            alt: medium.alt,
                                            width: medium.width,
                                            height: medium.height
                                        )
                                    }
                                )
                                .padding(.horizontal)
                            }

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
                                icon: "arrowshape.turn.up.left",
                                count: engagementState?.repliesCount ?? 0,
                                showsZeroCount: true,
                                accessibilityLabel: canPerformEngagementActions
                                    ? PostL10n.repliesTitle
                                    : PostL10n.viewRepliesAction,
                                onTap: {
                                    switch PostEngagementAccessPolicy.reply(
                                        isAuthenticated: canPerformEngagementActions,
                                        postID: engagementTargetID
                                    ) {
                                    case .composeReply:
                                        refreshPostOnSheetDismiss = false
                                        activeSheet = .reply
                                    case .viewReplies:
                                        viewReplies(using: scrollProxy)
                                    case .toggleShare, .viewShares:
                                        break
                                    }
                                }
                            )

                            EngagementToolbarButton(
                                icon: "arrow.2.squarepath",
                                count: engagementState?.sharesCount ?? 0,
                                showsZeroCount: true,
                                accessibilityLabel: canPerformEngagementActions
                                    ? PostL10n.sharesTitle
                                    : PostL10n.viewSharesAction,
                                accessibilityLongPressLabel: canPerformEngagementActions
                                    ? (sharePressActionsSwapped
                                        ? (engagementState?.hasShared == true
                                            ? PostL10n.unshareAction
                                            : PostL10n.shareAction)
                                        : PostL10n.viewSharesAction)
                                    : PostL10n.viewSharesAction,
                                tint: engagementState?.hasShared == true ? .green : .secondary,
                                isLoading: engagementState?.isSharing == true,
                                onTap: {
                                    handleShareTap()
                                },
                                onLongPress: {
                                    handleShareLongPress()
                                }
                            )

                            EngagementToolbarButton(
                                icon: viewerHasReacted ? "heart.fill" : "heart",
                                count: engagementState?.reactionsCount ?? 0,
                                showsZeroCount: true,
                                accessibilityLabel: ReactionL10n.title,
                                tint: viewerHasReacted ? .red : .secondary,
                                isLoading: isReacting,
                                onTap: presentReactionPicker
                            )

                            EngagementToolbarButton(
                                icon: "quote.bubble",
                                count: engagementState?.quotesCount ?? 0,
                                showsZeroCount: true,
                                accessibilityLabel: PostL10n.quotesTitle,
                                accessibilityLongPressLabel: quotePressActionsSwapped
                                    ? PostL10n.quoteAction
                                    : PostL10n.viewQuotesAction,
                                onTap: {
                                    handleQuoteTap()
                                },
                                onLongPress: {
                                    handleQuoteLongPress()
                                }
                            )

                            Spacer()

                            if canPerformEngagementActions {
                                Button {
                                    Task {
                                        await toggleBookmark()
                                    }
                                } label: {
                                    if isBookmarking {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: engagementState?.hasBookmarked == true ? "bookmark.fill" : "bookmark")
                                    }
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(engagementState?.hasBookmarked == true ? .yellow : .secondary)
                                .accessibilityLabel(
                                    engagementState?.hasBookmarked == true
                                        ? NSLocalizedString("bookmark.action.remove", comment: "Remove bookmark")
                                        : NSLocalizedString("bookmark.action.add", comment: "Add bookmark")
                                )
                            }

                            if let shareURL = post.resolvedShareURL {
                                ShareLink(item: shareURL) {
                                    Label(PostL10n.shareAction, systemImage: "square.and.arrow.up")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.borderless)
                            }

                            if canDelete(post: post) {
                                Button {
                                    requestDeletePost(post: post)
                                } label: {
                                    if isDeleting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                                .accessibilityLabel(NSLocalizedString("post.action.delete", comment: "Delete post"))
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                        Color.clear
                            .frame(height: 0)
                            .id(ScrollAnchor.replies)

                        // Replies section - only show if there are replies or more to load
                        if !replyEdges.isEmpty || hasMoreReplies {
                            Divider()
                                .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 12) {
                                Text(PostL10n.repliesTitle)
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(replyEdges.map { $0.node }, id: \.id) { reply in
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
                                        Button(PostL10n.loadMoreReplies) {
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
        }
        .navigationTitle(PostL10n.postTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await fetchPost()
        }
        .refreshable {
            await refreshPost()
        }
        .onReceive(NotificationCenter.default.publisher(for: .postContentDidChange)) { notification in
            handlePostContentNotification(notification)
        }
        .sheet(item: $activeSheet, onDismiss: {
            if let postID = pendingQuotedPostNavigation.consume() {
                refreshPostOnSheetDismiss = false
                navigationCoordinator.navigateToPost(id: postID)
            } else if refreshPostOnSheetDismiss {
                refreshPostOnSheetDismiss = false
                Task {
                    await refreshPost()
                }
            }
        }) { sheet in
            switch sheet {
            case .reply:
                if post != nil {
                    ComposeView(
                        replyToPostId: engagementTargetID
                    )
                }
            case .quote:
                if post != nil {
                    ComposeView(quotedPostId: engagementTargetID)
                }
            case let .reactors(reaction):
                ReactorsListView(reaction: reaction)
            case .shares:
                SharesListSheetView(
                    title: PostEngagementSheetL10n.sharesTitle,
                    state: sharesState,
                    emptyTitle: PostEngagementSheetL10n.sharesEmpty,
                    loadMoreTitle: PostEngagementSheetL10n.sharesLoadMore
                )
            case .quotesList:
                NavigationStack {
                    QuotesListSheetView(
                        state: quotesState,
                        emptyTitle: PostEngagementSheetL10n.quotesEmpty,
                        loadMoreTitle: PostEngagementSheetL10n.quotesLoadMore,
                        onPostSelected: { selectedId in
                            openQuotedPost(id: selectedId)
                        }
                    )
                    .navigationTitle(PostEngagementSheetL10n.quotesTitle)
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
                PostReactionSheetView(
                    reactionGroups: engagementState?.reactionGroups ?? [],
                    reactionInfos: reactionInfoState.items,
                    isLoadingReactionInfos: reactionInfoState.isLoading,
                    reactionInfosErrorMessage: reactionInfoState.errorMessage,
                    reactionMutationErrorMessage: engagementState?.reactionErrorMessage,
                    isSubmitting: isReacting,
                    onEmojiSelect: { emoji in
                        Task {
                            if let result = await toggleReaction(emoji: emoji) {
                                await synchronizeReactionMutation(result)
                            }
                        }
                    },
                    onRetryReactionInfos: {
                        Task {
                            await fetchReactionInfos()
                        }
                    },
                    onRetryReactionMutation: {
                        guard let emoji = reactionRetryEmoji else { return }
                        Task {
                            if let result = await toggleReaction(emoji: emoji) {
                                await synchronizeReactionMutation(result)
                            }
                        }
                    },
                    onReactorSelected: { handle in
                        activeSheet = nil
                        navigationCoordinator.navigateToProfile(handle: handle)
                    },
                    onClose: {
                        activeSheet = nil
                    }
                )
                .presentationDetents([.medium, .large])
            case .editArticle:
                if let post, let articleSourceId {
                    ArticleEditorView(
                        seed: ArticleEditSeed(
                            title: matchingOriginalArticleContent?.title ?? post.name ?? "",
                            content: originalArticleRawContent ?? "",
                            tags: articleTags,
                            articleId: post.id,
                            articleSourceId: articleSourceId,
                            language: matchingOriginalArticleContent?.language ?? articleLanguage,
                            allowLlmTranslation: articleAllowLlmTranslation
                        )
                    ) {
                        activeSheet = nil
                        Task {
                            await refreshPost()
                        }
                    }
                }
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
            PostReactionSheetView(
                reactionGroups: engagementState?.reactionGroups ?? [],
                reactionInfos: reactionInfoState.items,
                isLoadingReactionInfos: reactionInfoState.isLoading,
                reactionInfosErrorMessage: reactionInfoState.errorMessage,
                reactionMutationErrorMessage: engagementState?.reactionErrorMessage,
                isSubmitting: isReacting,
                onEmojiSelect: { emoji in
                    Task {
                        if let result = await toggleReaction(emoji: emoji) {
                            await synchronizeReactionMutation(result)
                        }
                    }
                },
                onRetryReactionInfos: {
                    Task {
                        await fetchReactionInfos()
                    }
                },
                onRetryReactionMutation: {
                    guard let emoji = reactionRetryEmoji else { return }
                    Task {
                        if let result = await toggleReaction(emoji: emoji) {
                            await synchronizeReactionMutation(result)
                        }
                    }
                },
                onReactorSelected: { handle in
                    showingReactionPicker = false
                    navigationCoordinator.navigateToProfile(handle: handle)
                },
                onClose: {
                    showingReactionPicker = false
                }
            )
            .frame(width: 360)
        }
        .alert(
            NSLocalizedString("share.error.title", comment: "Share error title"),
            isPresented: Binding(
                get: { engagementState?.shareErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        engagementState?.shareErrorMessage = nil
                    }
                }
            )
        ) {
            Button(NSLocalizedString("common.retry", comment: "Retry")) {
                performShareToggle()
            }
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {
                engagementState?.shareErrorMessage = nil
            }
        } message: {
            Text(engagementState?.shareErrorMessage ?? "")
        }
        .alert(
            NSLocalizedString("delete.error.title", comment: "Delete error title"),
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteErrorMessage = nil
                    }
                }
            )
        ) {
            Button(NSLocalizedString("compose.error.ok", comment: "OK button"), role: .cancel) {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
        .alert(
            NSLocalizedString("post.refresh.error.title", comment: "Post refresh error title"),
            isPresented: Binding(
                get: { failureState.refreshMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        failureState.refreshMessage = nil
                    }
                }
            )
        ) {
            Button(NSLocalizedString("common.retry", comment: "Retry")) {
                Task {
                    await refreshPost()
                }
            }
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {
                failureState.refreshMessage = nil
            }
        } message: {
            Text(failureState.refreshMessage ?? "")
        }
        .alert(
            NSLocalizedString("post.translation.error.title", comment: "Article translation error title"),
            isPresented: Binding(
                get: { failureState.translationMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        failureState.translationMessage = nil
                    }
                }
            )
        ) {
            if let translationRetryLanguage, let post {
                Button(NSLocalizedString("common.retry", comment: "Retry")) {
                    Task {
                        await loadArticleTranslation(postId: post.id, language: translationRetryLanguage)
                    }
                }
            }
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {
                failureState.translationMessage = nil
                translationRetryLanguage = nil
            }
        } message: {
            Text(failureState.translationMessage ?? "")
        }
        .confirmationDialog(
            engagementState?.hasShared == true
                ? NSLocalizedString("share.confirm.unshareTitle", comment: "Confirmation dialog title for undoing a share")
                : NSLocalizedString("share.confirm.shareTitle", comment: "Confirmation dialog title for sharing a post"),
            isPresented: $showingShareConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                engagementState?.hasShared == true
                    ? NSLocalizedString("share.confirm.unshareAction", comment: "Confirmation action to undo share")
                    : NSLocalizedString("share.confirm.shareAction", comment: "Confirmation action to share")
            ) {
                performShareToggle()
            }

            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            NSLocalizedString("delete.confirm.title", comment: "Delete confirmation title"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                NSLocalizedString("delete.confirm.action", comment: "Delete confirmation action"),
                role: .destructive
            ) {
                performDeletePost()
            }

            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
        }
    }

    private func fetchPost() async {
        isLoading = true
        failureState.beginInitialLoad()
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.PostDetailQuery(id: postId, repliesAfter: nil),
                cachePolicy: .networkOnly
            )

            if let errors = response.errors, !errors.isEmpty {
                failureState.failInitialLoad(message: errors.first?.message ?? "Unknown error")
                return
            }

            guard let fetchedPost = response.data?.node?.asPost else {
                failureState.failInitialLoad(message: "Post not found")
                return
            }

            failureState.completeInitialLoad()
            post = fetchedPost
            let article = response.data?.node?.asArticle
            articleContents = article?.contents ?? []
            articleTags = article?.tags ?? []
            articleLanguage = article?.language
            articleAllowLlmTranslation = article?.allowLlmTranslation ?? true
            articleSourceId = article?.sourceId
            translatedArticleContent = nil
            translatedArticleLanguage = nil
            showingOriginalArticle = true
            replyEdges = fetchedPost.replies.edges
            hasMoreReplies = fetchedPost.replies.pageInfo.hasNextPage
            repliesCursor = fetchedPost.replies.pageInfo.endCursor
            reconcileEngagementState(with: fetchedPost)
        } catch {
            #if DEBUG
                NSLog("PostDetail fetch failed for id \(postId): \(String(describing: error))")
            #endif
            failureState.failInitialLoad(message: "Failed to load post: \(error.localizedDescription)")
        }
    }

    private func loadMoreReplies() async {
        guard let cursor = repliesCursor, hasMoreReplies, !isLoadingMoreReplies else { return }

        isLoadingMoreReplies = true
        defer { isLoadingMoreReplies = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.PostDetailQuery(id: postId, repliesAfter: .some(cursor)),
                cachePolicy: .networkOnly
            )

            if let fetchedPost = response.data?.node?.asPost {
                let newReplies = fetchedPost.replies
                let existingReplyIds = Set(replyEdges.map { $0.node.id })
                replyEdges.append(contentsOf: newReplies.edges.filter { !existingReplyIds.contains($0.node.id) })

                hasMoreReplies = newReplies.pageInfo.hasNextPage
                repliesCursor = newReplies.pageInfo.endCursor
            }
        } catch {
            print("Error loading more replies: \(error)")
        }
    }

    private func handlePostContentNotification(_ notification: Notification) {
        guard let event = PostContentEventCenter.event(from: notification) else { return }
        if let isBookmarked = PostBookmarkContentEventRouter.bookmarkedState(
            from: event,
            targetPostID: engagementTargetID
        ) {
            engagementState?.hasBookmarked = isBookmarked
            return
        }

        let action = PostDetailContentEventRouter.route(
            event,
            displayedPostID: postId,
            engagementTargetID: engagementTargetID,
            loadedReplyIDs: Set(replyEdges.map { $0.node.id })
        )
        switch action {
        case .none:
            break
        case .dismiss:
            dismiss()
        case .refreshReplies:
            Task {
                await refreshReplies()
            }
        case let .removeReply(replyID):
            replyEdges.removeAll { $0.node.id == replyID }
            engagementState?.repliesCount = max(0, (engagementState?.repliesCount ?? 0) - 1)
        }
    }

    private func viewReplies(using scrollProxy: ScrollViewProxy) {
        let action = PostDetailReplyReadPolicy.action(
            hasPost: post != nil,
            loadedReplyCount: replyEdges.count,
            totalReplyCount: engagementState?.repliesCount ?? 0,
            hasRefreshFailure: failureState.refreshMessage != nil
        )

        scrollToReplies(using: scrollProxy)

        switch action {
        case .scroll:
            break
        case .refreshReplies:
            Task { @MainActor in
                await refreshReplies()
                scrollToReplies(using: scrollProxy)
            }
        case .reloadPost:
            Task { @MainActor in
                await fetchPost()
                scrollToReplies(using: scrollProxy)
            }
        }
    }

    private func scrollToReplies(using scrollProxy: ScrollViewProxy) {
        withAnimation(.easeInOut) {
            scrollProxy.scrollTo(ScrollAnchor.replies, anchor: .top)
        }
    }

    private func refreshReplies() async {
        failureState.beginRefresh()

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.PostDetailQuery(id: engagementTargetID, repliesAfter: nil),
                cachePolicy: .networkOnly
            )
            if let graphQLError = response.errors?.first {
                failureState.failRefresh(
                    message: refreshFailureMessage(details: graphQLError.message)
                )
                return
            }
            guard let fetchedPost = response.data?.node?.asPost else {
                failureState.failRefresh(message: refreshFailureMessage(details: nil))
                return
            }

            replyEdges = fetchedPost.replies.edges
            hasMoreReplies = fetchedPost.replies.pageInfo.hasNextPage
            repliesCursor = fetchedPost.replies.pageInfo.endCursor
            engagementState?.repliesCount = fetchedPost.engagementStats.replies
        } catch {
            if !PostEngagementMutationError.isCancellation(error) {
                failureState.failRefresh(
                    message: refreshFailureMessage(details: error.localizedDescription)
                )
            }
        }
    }

    private func refreshPost() async {
        failureState.beginRefresh()

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.PostDetailQuery(id: postId, repliesAfter: nil),
                cachePolicy: .networkOnly
            )

            if let errors = response.errors, !errors.isEmpty {
                failureState.failRefresh(
                    message: refreshFailureMessage(details: errors.first?.message)
                )
                return
            }

            guard let fetchedPost = response.data?.node?.asPost else {
                failureState.failRefresh(message: refreshFailureMessage(details: nil))
                return
            }

            post = fetchedPost
            let article = response.data?.node?.asArticle
            articleContents = article?.contents ?? []
            articleTags = article?.tags ?? []
            articleLanguage = article?.language
            articleAllowLlmTranslation = article?.allowLlmTranslation ?? true
            articleSourceId = article?.sourceId
            translatedArticleContent = nil
            translatedArticleLanguage = nil
            showingOriginalArticle = true
            replyEdges = fetchedPost.replies.edges
            hasMoreReplies = fetchedPost.replies.pageInfo.hasNextPage
            repliesCursor = fetchedPost.replies.pageInfo.endCursor
            reconcileEngagementState(with: fetchedPost)
        } catch {
            #if DEBUG
                NSLog("PostDetail refresh failed for id \(postId): \(String(describing: error))")
            #endif
            if !PostEngagementMutationError.isCancellation(error) {
                failureState.failRefresh(
                    message: refreshFailureMessage(details: error.localizedDescription)
                )
            }
        }
    }

    private func loadArticleTranslation(postId: String, language: String) async {
        let normalizedLanguage = normalizeLanguageIdentifier(language)
        if translatedArticleLanguage == normalizedLanguage, translatedArticleContent != nil {
            showingOriginalArticle = false
            return
        }

        failureState.beginTranslation()
        translationRetryLanguage = normalizedLanguage
        isLoadingArticleTranslation = true
        defer { isLoadingArticleTranslation = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ArticleTranslationQuery(id: postId, language: normalizedLanguage),
                cachePolicy: .networkOnly
            )
            if let graphQLError = response.errors?.first {
                failureState.failTranslation(
                    message: translationFailureMessage(details: graphQLError.message)
                )
                return
            }
            guard let content = response.data?.node?.asArticle?.contents.first else {
                failureState.failTranslation(message: translationFailureMessage(details: nil))
                return
            }
            translatedArticleContent = content
            translatedArticleLanguage = normalizedLanguage
            translationRetryLanguage = nil
            showingOriginalArticle = false
        } catch {
            if !PostEngagementMutationError.isCancellation(error) {
                failureState.failTranslation(
                    message: translationFailureMessage(details: error.localizedDescription)
                )
            }
        }
    }

    private func refreshFailureMessage(details: String?) -> String {
        guard let details, !details.isEmpty else {
            return NSLocalizedString("post.refresh.error.failed", comment: "Post refresh failed")
        }
        return String(
            format: NSLocalizedString(
                "post.refresh.error.failedWithDetails",
                comment: "Post refresh failed with details"
            ),
            details
        )
    }

    private func translationFailureMessage(details: String?) -> String {
        guard let details, !details.isEmpty else {
            return NSLocalizedString("post.translation.error.failed", comment: "Article translation failed")
        }
        return String(
            format: NSLocalizedString(
                "post.translation.error.failedWithDetails",
                comment: "Article translation failed with details"
            ),
            details
        )
    }

    private func openQuotedPost(id: String) {
        pendingQuotedPostNavigation.schedule(postID: id)
        activeSheet = nil
    }

    private func toggleShare() async {
        guard var currentState = engagementState,
              let attempt = currentState.beginShareToggle()
        else {
            return
        }
        engagementState = currentState

        do {
            let result = try await PostEngagementMutationService.setShared(
                postID: attempt.targetPostID,
                desiredHasShared: attempt.desiredHasShared
            )
            engagementState?.completeShare(
                attempt,
                hasShared: result.hasShared,
                sharesCount: result.sharesCount
            )
        } catch {
            if PostEngagementMutationError.isCancellation(error) {
                engagementState?.cancelShare(attempt)
            } else {
                engagementState?.failShare(
                    attempt,
                    message: PostEngagementMutationError.userMessage(for: error)
                )
            }
        }
    }

    private func toggleBookmark() async {
        guard !isBookmarking else { return }
        guard AuthManager.shared.currentAccount != nil else { return }

        guard let previousState = engagementState?.hasBookmarked else { return }
        isBookmarking = true
        engagementState?.hasBookmarked.toggle()
        defer { isBookmarking = false }

        do {
            if previousState {
                let response = try await apolloClient.perform(
                    mutation: HackersPub.UnbookmarkPostMutation(postId: engagementTargetID)
                )
                if let payload = response.data?.unbookmarkPost.asUnbookmarkPostPayload {
                    engagementState?.hasBookmarked = PostBookmarkChangePropagation.resolve(
                        postID: engagementTargetID,
                        authoritativeState: payload.post.viewerHasBookmarked,
                        fallbackState: previousState,
                        onChange: onBookmarkChanged
                    )
                } else {
                    engagementState?.hasBookmarked = previousState
                }
            } else {
                let response = try await apolloClient.perform(
                    mutation: HackersPub.BookmarkPostMutation(postId: engagementTargetID)
                )
                if let payload = response.data?.bookmarkPost.asBookmarkPostPayload {
                    engagementState?.hasBookmarked = PostBookmarkChangePropagation.resolve(
                        postID: engagementTargetID,
                        authoritativeState: payload.post.viewerHasBookmarked,
                        fallbackState: previousState,
                        onChange: onBookmarkChanged
                    )
                } else {
                    engagementState?.hasBookmarked = previousState
                }
            }
        } catch {
            engagementState?.hasBookmarked = previousState
            print("Error toggling bookmark: \(error)")
        }
    }

    private func performShareToggle() {
        guard AuthManager.shared.currentAccount != nil else { return }
        Task {
            await toggleShare()
        }
    }

    private func requestShareToggle() {
        guard AuthManager.shared.currentAccount != nil else {
            presentSharesSheet()
            return
        }
        if confirmBeforeShare {
            showingShareConfirmation = true
        } else {
            performShareToggle()
        }
    }

    private func deletePost() async {
        guard !isDeleting else { return }
        guard AuthManager.shared.currentAccount != nil else {
            deleteErrorMessage = NSLocalizedString("delete.error.notAuthenticated", comment: "Delete requires sign in")
            return
        }

        isDeleting = true
        deleteErrorMessage = nil
        defer { isDeleting = false }

        do {
            let response = try await apolloClient.perform(
                mutation: HackersPub.DeletePostMutation(id: postId)
            )

            if response.data?.deletePost.asDeletePostPayload != nil {
                PostContentEventCenter.publish(.postDeleted(postID: postId))
                NotificationCenter.default.post(name: Notification.Name("RefreshTimeline"), object: nil)
                dismiss()
            } else if let invalidInput = response.data?.deletePost.asInvalidInputError {
                deleteErrorMessage = String(
                    format: NSLocalizedString("delete.error.invalidInput", comment: "Delete invalid input error"),
                    invalidInput.inputPath
                )
            } else if response.data?.deletePost.asNotAuthenticatedError != nil {
                deleteErrorMessage = NSLocalizedString("delete.error.notAuthenticated", comment: "Delete requires sign in")
            } else if response.data?.deletePost.asSharedPostDeletionNotAllowedError != nil {
                deleteErrorMessage = NSLocalizedString("delete.error.sharedPostNotAllowed", comment: "Shared post deletion not allowed")
            } else {
                deleteErrorMessage = NSLocalizedString("delete.error.failed", comment: "Delete failed")
            }
        } catch {
            deleteErrorMessage = String(
                format: NSLocalizedString("delete.error.failedWithDetails", comment: "Delete failed with details"),
                error.localizedDescription
            )
        }
    }

    private func performDeletePost() {
        Task {
            await deletePost()
        }
    }

    private func requestDeletePost(post: HackersPub.PostDetailQuery.Data.Node.AsPost) {
        guard canDelete(post: post) else { return }
        if confirmBeforeDelete {
            showingDeleteConfirmation = true
        } else {
            performDeletePost()
        }
    }

    private func presentSharesSheet() {
        refreshPostOnSheetDismiss = false
        activeSheet = .shares
        Task {
            await sharesState.reload()
        }
    }

    private func handleShareTap() {
        performShareAccessAction(isAlternateAction: false)
    }

    private func handleShareLongPress() {
        performShareAccessAction(isAlternateAction: true)
    }

    private func performShareAccessAction(isAlternateAction: Bool) {
        switch PostEngagementAccessPolicy.share(
            isAuthenticated: canPerformEngagementActions,
            actionsSwapped: sharePressActionsSwapped,
            isAlternateAction: isAlternateAction,
            postID: engagementTargetID
        ) {
        case .toggleShare:
            performShareToggle()
        case .viewShares:
            presentSharesSheet()
        case .composeReply, .viewReplies:
            break
        }
    }

    private func presentQuoteComposer() {
        guard AuthManager.shared.currentAccount != nil else {
            presentQuotesSheet()
            return
        }
        refreshPostOnSheetDismiss = true
        activeSheet = .quote
    }

    private func presentQuotesSheet() {
        refreshPostOnSheetDismiss = false
        activeSheet = .quotesList
        Task {
            await quotesState.reload()
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

    private func presentReactionPicker() {
        engagementState?.prepareReactionPicker()
        reactionRetryEmoji = nil
        if useReactionPopover {
            showingReactionPicker = true
        } else {
            refreshPostOnSheetDismiss = false
            activeSheet = .reactionPicker
        }

        Task {
            await fetchReactionInfos()
        }
    }

    private func fetchReactionInfos() async {
        guard reactionInfoState.beginLoading() else { return }
        var coordinator = reactionCoordinator
            ?? PostReactionRequestCoordinator(targetPostID: engagementTargetID)
        coordinator.setTargetPostID(engagementTargetID)
        guard let request = coordinator.beginInfoLoad() else { return }
        reactionCoordinator = coordinator

        do {
            let result = try await PostReactionInfoService.fetch(postID: request.targetPostID)
            guard reactionCoordinator?.shouldApply(request) == true else { return }
            reactionInfoState.succeed(items: result.infos)
            engagementState?.reconcileReactions(groups: result.groups, totalCount: result.totalCount)
        } catch {
            guard reactionCoordinator?.shouldApply(request) == true else { return }
            if PostEngagementMutationError.isCancellation(error) {
                reactionInfoState.cancel()
            } else {
                reactionInfoState.fail(
                    message: (error as? LocalizedError)?.errorDescription
                        ?? PostReactionInfoError.server(error.localizedDescription).localizedDescription
                )
            }
        }
    }

    private func applyReactionLocally(emoji: String, add: Bool) {
        engagementState?.applyReaction(emoji: emoji, adding: add)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func toggleReaction(emoji: String) async -> PostReactionMutationResult? {
        guard !isReacting else { return nil }
        guard AuthManager.shared.currentAccount != nil else {
            engagementState?.reactionErrorMessage = ReactionL10n.signInRequired
            reactionRetryEmoji = emoji
            return nil
        }

        isReacting = true
        defer { isReacting = false }

        guard var coordinator = reactionCoordinator,
              let state = engagementState
        else {
            return nil
        }
        coordinator.setTargetPostID(state.target.postID)
        guard let attempt = coordinator.beginMutation() else { return nil }
        reactionCoordinator = coordinator
        reactionInfoState.cancel()
        let rollback = state.reactionRollbackSnapshot()

        let shouldRemove = ReactionGroupIndex.viewerHasReacted(
            to: emoji,
            in: state.reactionGroups
        )
        let mutationEmoji = shouldRemove
            ? ReactionGroupIndex.mutationEmoji(
                for: emoji,
                in: state.reactionGroups
            )
            : emoji
        applyReactionLocally(emoji: mutationEmoji, add: !shouldRemove)

        do {
            let result = try await PostEngagementMutationService.setReaction(
                postID: attempt.targetPostID,
                emoji: mutationEmoji,
                adding: !shouldRemove
            )
            reactionRetryEmoji = nil
            guard var currentCoordinator = reactionCoordinator else { return nil }
            let completion = currentCoordinator.finish(attempt, outcome: .success)
            reactionCoordinator = currentCoordinator
            switch completion {
            case .synchronize:
                return result
            case .ignore, .rollbackWithoutError, .rollbackWithError:
                return nil
            }
        } catch {
            guard var currentCoordinator = reactionCoordinator else { return nil }
            let completion = currentCoordinator.finish(
                attempt,
                outcome: PostEngagementMutationError.isCancellation(error) ? .cancelled : .failure
            )
            reactionCoordinator = currentCoordinator
            switch completion {
            case .rollbackWithoutError:
                engagementState?.restoreReactionState(from: rollback)
            case .rollbackWithError:
                engagementState?.restoreReactionState(from: rollback)
                engagementState?.reactionErrorMessage = PostReactionMutationError.userMessage(
                    for: error,
                    adding: !shouldRemove
                )
                reactionRetryEmoji = emoji
            case .ignore, .synchronize:
                break
            }
            return nil
        }
    }

    private func synchronizeReactionMutation(_ result: PostReactionMutationResult) async {
        switch result.refreshScope {
        case .reactionDetails:
            await fetchReactionInfos()
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
}

struct ReactorInfo: Identifiable, Equatable {
    let id: String
    let name: String?
    let handle: String
    let avatarUrl: String
}

struct ReactionGroupInfo: Identifiable, Equatable {
    let emoji: String
    let customEmojiUrl: String?
    let reactors: [ReactorInfo]
    let totalCount: Int

    var id: String {
        if let customEmojiUrl {
            return "custom:\(emoji):\(customEmojiUrl)"
        }
        return "emoji:\(emoji)"
    }
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

struct PostReactionSheetView: View {
    let reactionGroups: [ReactionGroupSnapshot]
    let reactionInfos: [ReactionGroupInfo]
    let isLoadingReactionInfos: Bool
    let reactionInfosErrorMessage: String?
    let reactionMutationErrorMessage: String?
    let isSubmitting: Bool
    let onEmojiSelect: (String) -> Void
    let onRetryReactionInfos: () -> Void
    let onRetryReactionMutation: () -> Void
    let onReactorSelected: (String) -> Void
    let onClose: () -> Void

    private var sortedReactionInfos: [ReactionGroupInfo] {
        reactionInfos.sorted { lhs, rhs in
            if lhs.totalCount != rhs.totalCount {
                return lhs.totalCount > rhs.totalCount
            }
            return lhs.emoji < rhs.emoji
        }
    }

    private var standardGroupsByEmoji: [String: ReactionGroupSnapshot] {
        ReactionGroupIndex.standardGroupsByEmoji(reactionGroups)
    }

    private let reactionColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(ReactionL10n.title)
                    .font(.headline)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.28), lineWidth: 0.7)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ReactionL10n.close)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if let reactionMutationErrorMessage {
                        ReactionPickerErrorFeedback(
                            message: reactionMutationErrorMessage,
                            retryTitle: NSLocalizedString("common.retry", comment: "Retry"),
                            onRetry: onRetryReactionMutation
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString(
                            "reaction.sheet.addReaction",
                            comment: "Add reaction section title"
                        ))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                        LazyVGrid(columns: reactionColumns, spacing: 8) {
                            ForEach(supportedReactionEmojis, id: \.self) { emoji in
                                let existingGroup = standardGroupsByEmoji[emoji]
                                ReactionEmojiButton(
                                    emoji: emoji,
                                    count: existingGroup?.totalCount ?? 0,
                                    isSelected: existingGroup?.viewerHasReacted == true,
                                    isDisabled: isSubmitting,
                                    onTap: {
                                        onEmojiSelect(emoji)
                                    }
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString(
                            "reaction.sheet.reactors",
                            comment: "Reaction reactors section title"
                        ))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                        if let reactionInfosErrorMessage {
                            ReactionPickerErrorFeedback(
                                message: reactionInfosErrorMessage,
                                retryTitle: NSLocalizedString(
                                    "reaction.info.error.retry",
                                    comment: "Retry reaction information load"
                                ),
                                onRetry: onRetryReactionInfos
                            )
                        }

                        if isLoadingReactionInfos {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(NSLocalizedString(
                                    "reaction.sheet.loadingReactors",
                                    comment: "Loading reaction reactors message"
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 18)
                        } else if sortedReactionInfos.isEmpty, reactionInfosErrorMessage == nil {
                            ContentUnavailableView(
                                NSLocalizedString(
                                    "reaction.empty",
                                    comment: "No reactions yet message"
                                ),
                                systemImage: "heart"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(sortedReactionInfos) { reaction in
                                    ReactionReactorsGroupView(
                                        reaction: reaction,
                                        onReactorSelected: onReactorSelected
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct ReactionPickerErrorFeedback: View {
    let message: String
    let retryTitle: String
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.bordered)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ReactionEmojiButton: View {
    let emoji: String
    let count: Int
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(emoji)
                    .font(.title3)

                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .accessibilityLabel(String(format: ReactionL10n.reactedWithFormat, emoji))
    }
}

private struct ReactionReactorsGroupView: View {
    let reaction: ReactionGroupInfo
    let onReactorSelected: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                reactionIcon

                Text("\(reaction.totalCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if reaction.reactors.isEmpty {
                Text(NSLocalizedString(
                    "reaction.reactors.notLoaded",
                    comment: "Reaction reactors unavailable message"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(reaction.reactors) { reactor in
                        Button {
                            onReactorSelected(reactor.handle)
                        } label: {
                            HStack(spacing: 12) {
                                KFImage(URL(string: reactor.avatarUrl))
                                    .placeholder {
                                        Color.gray.opacity(0.2)
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 34, height: 34)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    if let name = reactor.name {
                                        HTMLTextView(html: name, font: .subheadline)
                                            .lineLimit(1)
                                    }
                                    Text(reactor.handle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if reactor.id != reaction.reactors.last?.id {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var reactionIcon: some View {
        if let customEmojiUrl = reaction.customEmojiUrl, let url = URL(string: customEmojiUrl) {
            KFImage(url)
                .placeholder {
                    Text(reaction.emoji)
                        .font(.title3)
                }
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
        } else {
            Text(reaction.emoji)
                .font(.title3)
        }
    }
}
