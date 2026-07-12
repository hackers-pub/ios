@preconcurrency import Apollo
import Foundation

// swiftlint:disable file_length

enum PostL10n {
    static let reposted = localized("post.reposted")
    static let replyingTo = localized("post.replyingTo")
    static let repliesTitle = localized("post.replies.title")
    static let viewRepliesAction = localized("post.replies.viewAction")
    static let loadMoreReplies = localized("post.replies.loadMore")
    static let postTitle = localized("post.title")
    static let shareAction = localized("post.share.action")
    static let unshareAction = localized("share.confirm.unshareAction")
    static let sharesTitle = localized("post.shares.title")
    static let viewSharesAction = localized("post.shares.showAction")
    static let noShares = localized("post.shares.empty")
    static let loadMoreShares = localized("post.shares.loadMore")
    static let quotesTitle = localized("post.quotes.title")
    static let quoteAction = localized("post.quotes.createAction")
    static let viewQuotesAction = localized("post.quotes.showAction")
    static let noQuotes = localized("post.quotes.empty")
    static let loadMoreQuotes = localized("post.quotes.loadMore")
    static let loadMore = localized("post.engagement.loadMore")
    static let retry = localized("common.retry")
    static let unknownError = localized("common.error.unknown")
    static let postNotFound = localized("post.error.notFound")

    static func failedToLoadPost(details: String) -> String {
        formatted("post.error.loadFailed", details)
    }

    static func failedToLoadShares(details: String) -> String {
        formatted("post.shares.error.loadFailed", details)
    }

    static func failedToLoadMoreShares(details: String) -> String {
        formatted("post.shares.error.loadMoreFailed", details)
    }

    static func failedToLoadQuotes(details: String) -> String {
        formatted("post.quotes.error.loadFailed", details)
    }

    static func failedToLoadMoreQuotes(details: String) -> String {
        formatted("post.quotes.error.loadMoreFailed", details)
    }

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "Post interaction copy")
    }

    private static func formatted(_ key: String, _ details: String) -> String {
        String(format: localized(key), details)
    }
}

enum DeferredMenuMainActor {
    static func perform(_ operation: @escaping @MainActor () async -> Void) {
        Task { @MainActor in
            await operation()
        }
    }
}

enum PostBookmarkChangePropagation {
    static func resolve(
        postID: String,
        authoritativeState: Bool?,
        fallbackState: Bool,
        onChange: ((String, Bool) -> Void)?,
        center: NotificationCenter = .default
    ) -> Bool {
        guard let authoritativeState else { return fallbackState }
        onChange?(postID, authoritativeState)
        PostContentEventCenter.publish(
            .bookmarkChanged(postID: postID, isBookmarked: authoritativeState),
            center: center
        )
        return authoritativeState
    }
}

struct EngagementToolbarAccessibility: Equatable {
    static let minimumHitSize = 44

    let label: String
    let value: String
    let alternateActionName: String?

    init(label: String, count: Int, alternateActionName: String? = nil) {
        self.label = label
        value = String(count)
        self.alternateActionName = alternateActionName
    }
}

struct PendingSheetPostNavigation: Equatable {
    private(set) var pendingPostID: String?

    mutating func schedule(postID: String) {
        pendingPostID = postID
    }

    mutating func consume() -> String? {
        defer { pendingPostID = nil }
        return pendingPostID
    }
}

enum PostEngagementAccessAction: Equatable {
    case composeReply(postID: String)
    case viewReplies(postID: String)
    case toggleShare(postID: String)
    case viewShares(postID: String)
}

enum PostEngagementAccessPolicy {
    static func reply(
        isAuthenticated: Bool,
        postID: String
    ) -> PostEngagementAccessAction {
        isAuthenticated ? .composeReply(postID: postID) : .viewReplies(postID: postID)
    }

    static func share(
        isAuthenticated: Bool,
        actionsSwapped: Bool,
        isAlternateAction: Bool,
        postID: String
    ) -> PostEngagementAccessAction {
        guard isAuthenticated else { return .viewShares(postID: postID) }
        return actionsSwapped == isAlternateAction
            ? .toggleShare(postID: postID)
            : .viewShares(postID: postID)
    }
}

enum PostDetailReplyReadAction: Equatable {
    case scroll
    case refreshReplies
    case reloadPost
}

enum PostDetailReplyReadPolicy {
    static func action(
        hasPost: Bool,
        loadedReplyCount: Int,
        totalReplyCount: Int,
        hasRefreshFailure: Bool
    ) -> PostDetailReplyReadAction {
        guard hasPost else { return .reloadPost }
        if hasRefreshFailure || (loadedReplyCount == 0 && totalReplyCount > 0) {
            return .refreshReplies
        }
        return .scroll
    }
}

enum PostEngagementRoute: CaseIterable {
    case displayedPost
    case reply
    case share
    case bookmark
    case reaction
    case sharesList
    case quote
    case quotesList
}

enum ReactionPickerPresentation: Equatable {
    case sheet
    case popover
}

enum EngagementToolbarGestureAction: Equatable {
    case tap
    case longPress
}

enum EngagementToolbarGesturePolicy {
    static func dispatch(
        _ action: EngagementToolbarGestureAction,
        onTap: () -> Void,
        onLongPress: (() -> Void)?
    ) {
        switch action {
        case .tap:
            onTap()
        case .longPress:
            onLongPress?()
        }
    }
}

enum PostContentEvent: Equatable {
    case replyCreated(parentPostID: String, replyPostID: String)
    case postDeleted(postID: String)
    case bookmarkChanged(postID: String, isBookmarked: Bool)

    static func replyCreated(
        createdPostID: String,
        replyTargetID: String?
    ) -> PostContentEvent? {
        guard let replyTargetID else { return nil }
        return .replyCreated(parentPostID: replyTargetID, replyPostID: createdPostID)
    }
}

extension Notification.Name {
    static let postContentDidChange = Notification.Name("PostContentDidChange")
}

enum PostContentEventCenter {
    static func publish(
        _ event: PostContentEvent,
        center: NotificationCenter = .default
    ) {
        center.post(name: .postContentDidChange, object: event)
    }

    static func event(from notification: Notification) -> PostContentEvent? {
        notification.object as? PostContentEvent
    }
}

enum PostDetailContentEventAction: Equatable {
    case none
    case dismiss
    case refreshReplies
    case removeReply(String)
}

enum PostDetailContentEventRouter {
    static func route(
        _ event: PostContentEvent,
        displayedPostID: String,
        engagementTargetID: String,
        loadedReplyIDs: Set<String>
    ) -> PostDetailContentEventAction {
        switch event {
        case let .replyCreated(parentPostID, _):
            return parentPostID == engagementTargetID ? .refreshReplies : .none
        case let .postDeleted(postID):
            if postID == displayedPostID || postID == engagementTargetID {
                return .dismiss
            }
            return loadedReplyIDs.contains(postID) ? .removeReply(postID) : .none
        case .bookmarkChanged:
            return .none
        }
    }
}

struct ReactionInfoLoadState<Item: Equatable>: Equatable {
    var items: [Item]
    var isLoading = false
    var errorMessage: String?

    init(items: [Item] = []) {
        self.items = items
    }

    mutating func beginLoading(force: Bool = false) -> Bool {
        guard force || !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        return true
    }

    mutating func succeed(items: [Item]) {
        self.items = items
        isLoading = false
        errorMessage = nil
    }

    mutating func fail(message: String) {
        isLoading = false
        errorMessage = message
    }

    mutating func cancel() {
        isLoading = false
        errorMessage = nil
    }
}

struct PostDetailFailureState: Equatable {
    var blockingMessage: String?
    var refreshMessage: String?
    var translationMessage: String?

    mutating func beginInitialLoad() {
        blockingMessage = nil
    }

    mutating func completeInitialLoad() {
        blockingMessage = nil
    }

    mutating func failInitialLoad(message: String) {
        blockingMessage = message
    }

    mutating func beginRefresh() {
        refreshMessage = nil
    }

    mutating func failRefresh(message: String) {
        refreshMessage = message
    }

    mutating func beginTranslation() {
        translationMessage = nil
    }

    mutating func failTranslation(message: String) {
        translationMessage = message
    }
}

struct PostEngagementTarget: Equatable {
    let wrapperPostID: String
    let postID: String

    var isRepost: Bool {
        wrapperPostID != postID
    }

    func postID(for _: PostEngagementRoute) -> String {
        postID
    }
}

struct PostShareAttempt: Equatable {
    let targetPostID: String
    let generation: Int
    let desiredHasShared: Bool
    let previousHasShared: Bool
    let previousSharesCount: Int
}

struct PostShareMutationResult: Equatable {
    let hasShared: Bool
    let sharesCount: Int
}

enum PostEngagementRefreshScope: Equatable {
    case reactionDetails
}

struct PostReactionMutationResult: Equatable {
    let refreshScope: PostEngagementRefreshScope

    static let success = PostReactionMutationResult(refreshScope: .reactionDetails)
}

enum PostEngagementMutationError: Error, Equatable, LocalizedError {
    case invalidInput(String)
    case notAuthenticated
    case server(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case let .invalidInput(inputPath):
            return String(
                format: NSLocalizedString("share.error.invalidInput", comment: "Share invalid input error"),
                inputPath
            )
        case .notAuthenticated:
            return NSLocalizedString("share.error.notAuthenticated", comment: "Share requires sign in")
        case let .server(message):
            return String(
                format: NSLocalizedString("share.error.failedWithDetails", comment: "Share failed with details"),
                message
            )
        case .unexpectedResponse:
            return NSLocalizedString("share.error.failed", comment: "Share failed")
        }
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let error = error as NSError
        return error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled
    }

    static func userMessage(for error: Error) -> String {
        if let error = error as? PostEngagementMutationError {
            return error.localizedDescription
        }

        return String(
            format: NSLocalizedString("share.error.failedWithDetails", comment: "Share failed with details"),
            error.localizedDescription
        )
    }
}

enum PostEngagementMutationService {
    static func setShared(
        postID: String,
        desiredHasShared: Bool
    ) async throws -> PostShareMutationResult {
        if desiredHasShared {
            let response = try await apolloClient.perform(
                mutation: HackersPub.SharePostMutation(postId: postID)
            )
            if let graphQLError = response.errors?.first {
                throw PostEngagementMutationError.server(
                    graphQLError.message ?? NSLocalizedString("share.error.failed", comment: "Share failed")
                )
            }
            let result = response.data?.sharePost
            if let payload = result?.asSharePostPayload {
                return PostShareMutationResult(
                    hasShared: payload.originalPost.viewerHasShared,
                    sharesCount: payload.originalPost.engagementStats.shares
                )
            }
            if let invalidInput = result?.asInvalidInputError {
                throw PostEngagementMutationError.invalidInput(invalidInput.inputPath)
            }
            if result?.asNotAuthenticatedError != nil {
                throw PostEngagementMutationError.notAuthenticated
            }
        } else {
            let response = try await apolloClient.perform(
                mutation: HackersPub.UnsharePostMutation(postId: postID)
            )
            if let graphQLError = response.errors?.first {
                throw PostEngagementMutationError.server(
                    graphQLError.message ?? NSLocalizedString("share.error.failed", comment: "Share failed")
                )
            }
            let result = response.data?.unsharePost
            if let payload = result?.asUnsharePostPayload {
                return PostShareMutationResult(
                    hasShared: payload.originalPost.viewerHasShared,
                    sharesCount: payload.originalPost.engagementStats.shares
                )
            }
            if let invalidInput = result?.asInvalidInputError {
                throw PostEngagementMutationError.invalidInput(invalidInput.inputPath)
            }
            if result?.asNotAuthenticatedError != nil {
                throw PostEngagementMutationError.notAuthenticated
            }
        }

        throw PostEngagementMutationError.unexpectedResponse
    }

    static func setReaction(
        postID: String,
        emoji: String,
        adding: Bool
    ) async throws -> PostReactionMutationResult {
        if adding {
            let response = try await apolloClient.perform(
                mutation: HackersPub.AddReactionToPostMutation(postId: postID, emoji: emoji)
            )
            if let graphQLError = response.errors?.first {
                throw PostReactionMutationError.server(graphQLError.message)
            }
            let result = response.data?.addReactionToPost
            if let payload = result?.asAddReactionToPostPayload, payload.reaction != nil {
                return .success
            }
            if let invalidInput = result?.asInvalidInputError {
                throw PostReactionMutationError.invalidInput(invalidInput.inputPath)
            }
            if result?.asNotAuthenticatedError != nil {
                throw PostReactionMutationError.notAuthenticated
            }
        } else {
            let response = try await apolloClient.perform(
                mutation: HackersPub.RemoveReactionFromPostMutation(postId: postID, emoji: emoji)
            )
            if let graphQLError = response.errors?.first {
                throw PostReactionMutationError.server(graphQLError.message)
            }
            let result = response.data?.removeReactionFromPost
            if let payload = result?.asRemoveReactionFromPostPayload, payload.success {
                return .success
            }
            if let invalidInput = result?.asInvalidInputError {
                throw PostReactionMutationError.invalidInput(invalidInput.inputPath)
            }
            if result?.asNotAuthenticatedError != nil {
                throw PostReactionMutationError.notAuthenticated
            }
        }

        throw PostReactionMutationError.unexpectedResponse
    }
}

enum PostReactionMutationError: Error, Equatable {
    case invalidInput(String)
    case notAuthenticated
    case server(String?)
    case unexpectedResponse

    func userMessage(adding: Bool) -> String {
        switch self {
        case .notAuthenticated:
            return ReactionL10n.signInRequired
        case let .invalidInput(inputPath):
            return String(
                format: NSLocalizedString("reaction.error.invalidInput", comment: "Reaction invalid input error"),
                inputPath
            )
        case .server, .unexpectedResponse:
            return adding ? ReactionL10n.unableToAdd : ReactionL10n.unableToRemove
        }
    }

    static func userMessage(for error: Error, adding: Bool) -> String {
        if let error = error as? PostReactionMutationError {
            return error.userMessage(adding: adding)
        }
        return adding ? ReactionL10n.unableToAdd : ReactionL10n.unableToRemove
    }
}

struct PostReactionInfoResult {
    let infos: [ReactionGroupInfo]
    let groups: [ReactionGroupSnapshot]
    let totalCount: Int
}

enum PostReactionInfoError: Error, LocalizedError {
    case server(String?)
    case postNotFound

    var errorDescription: String? {
        switch self {
        case let .server(message):
            guard let message, !message.isEmpty else {
                return NSLocalizedString("reaction.info.error.failed", comment: "Reaction info load failed")
            }
            return String(
                format: NSLocalizedString(
                    "reaction.info.error.failedWithDetails",
                    comment: "Reaction info load failed with details"
                ),
                message
            )
        case .postNotFound:
            return NSLocalizedString("reaction.info.error.postNotFound", comment: "Reaction post not found")
        }
    }
}

enum PostReactionInfoService {
    static func fetch(postID: String) async throws -> PostReactionInfoResult {
        let response = try await apolloClient.fetch(
            query: HackersPub.PostDetailQuery(id: postID, repliesAfter: nil),
            cachePolicy: .networkOnly
        )
        if let graphQLError = response.errors?.first {
            throw PostReactionInfoError.server(graphQLError.message)
        }
        guard let post = response.data?.node?.asPost else {
            throw PostReactionInfoError.postNotFound
        }

        return PostReactionInfoResult(
            infos: post.reactionGroups.map(info),
            groups: post.reactionGroupsSnapshot,
            totalCount: post.engagementStats.reactions
        )
    }

    private static func info(
        from group: HackersPub.PostDetailQuery.Data.Node.AsPost.ReactionGroup
    ) -> ReactionGroupInfo {
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
        }
        if let customGroup = group.asCustomEmojiReactionGroup {
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
