@preconcurrency import Apollo
import Kingfisher
import SwiftUI
import UIKit

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
    var iri: String { get }
    var sharedPost: SharedPostType? { get }
    var quotedPost: QuotedPostType? { get }
    var engagementStats: EngagementStatsType { get }
    var viewerHasShared: Bool { get }

    var mentionedHandles: [String] { get }
    var isArticle: Bool { get }
}

extension PostProtocol {
    var resolvedShareURL: URL? {
        if let url {
            let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedURL.isEmpty, let resolvedURL = URL(string: trimmedURL) {
                return resolvedURL
            }
        }

        let trimmedIri = iri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIri.isEmpty else { return nil }
        return URL(string: trimmedIri)
    }
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

private enum SneakPeekPreviewLayout {
    static let height: CGFloat = 560

    static var width: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return min(380, max(280, screenWidth - 24))
    }
}

private func withPreviewEnvironment<V: View>(
    _ view: V,
    authManager: AuthManager,
    navigationCoordinator: NavigationCoordinator,
    externalURLRouter: ExternalURLRouter
) -> some View {
    view
        .environment(authManager)
        .environment(navigationCoordinator)
        .environment(externalURLRouter)
        .environmentObject(FontSettingsManager.shared)
}

struct PostSneakPeekModifier: ViewModifier {
    let postId: String?
    let actorHandle: String?
    let shareURL: URL?
    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(ExternalURLRouter.self) private var externalURLRouter
    @State private var relationship: ActorRelationshipState?
    @State private var relationshipActionErrorMessage: String?
    @State private var isApplyingRelationshipAction = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if let postId {
            content
                .task(id: actorHandle) {
                    await loadRelationship()
                }
                .uiContextMenu(
                    makeConfiguration: {
                        makePostContextMenuConfiguration(postId: postId)
                    },
                    onCommit: {
                        navigationCoordinator.navigateToPost(id: postId)
                    }
                )
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
        } else {
            content
        }
    }

    private func loadRelationship(cachePolicy: CachePolicy.Query.SingleResponse = .networkFirst) async {
        guard let actorHandle else {
            relationship = nil
            return
        }

        do {
            relationship = try await ActorRelationshipService.fetch(handle: actorHandle, cachePolicy: cachePolicy)
        } catch {
            relationship = nil
        }
    }

    private func performRelationshipAction(_ action: ActorRelationshipAction, handle: String) {
        guard authManager.isAuthenticated else { return }
        guard !isApplyingRelationshipAction else { return }

        Task {
            isApplyingRelationshipAction = true
            defer { isApplyingRelationshipAction = false }

            do {
                let currentRelationship: ActorRelationshipState
                if let relationship {
                    currentRelationship = relationship
                } else if let fetched = try await ActorRelationshipService.fetch(handle: handle, cachePolicy: .networkOnly) {
                    currentRelationship = fetched
                    self.relationship = fetched
                } else {
                    throw ActorRelationshipServiceError.actorNotFound
                }

                guard !currentRelationship.isViewer else { return }

                try await ActorRelationshipService.perform(action: action, actorId: currentRelationship.actorId)
                relationship = try await ActorRelationshipService.fetch(handle: handle, cachePolicy: .networkOnly)
            } catch {
                relationshipActionErrorMessage = error.localizedDescription
            }
        }
    }

    private func makePostContextMenuConfiguration(postId: String) -> UIContextMenuConfiguration {
        UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: {
                let preview = withPreviewEnvironment(
                    PostDetailView(postId: postId)
                        .frame(width: SneakPeekPreviewLayout.width, height: SneakPeekPreviewLayout.height)
                        .ignoresSafeArea(),
                    authManager: authManager,
                    navigationCoordinator: navigationCoordinator,
                    externalURLRouter: externalURLRouter
                )
                let controller = UIHostingController(rootView: preview)
                controller.view.backgroundColor = .systemBackground
                controller.view.insetsLayoutMarginsFromSafeArea = false
                controller.view.directionalLayoutMargins = .zero
                return controller
            },
            actionProvider: { _ in
                makePostContextMenu()
            }
        )
    }

    private func makePostContextMenu() -> UIMenu {
        var children: [UIMenuElement] = []

        if let shareURL {
            let shareAction = UIAction(
                title: NSLocalizedString("sneakpeek.action.sharePost", comment: "Share post"),
                image: UIImage(systemName: "square.and.arrow.up")
            ) { _ in
                ShareSheetPresenter.present(items: [shareURL])
            }
            children.append(shareAction)
        }

        if let actorHandle, let userMenu = makeUserMenu(handle: actorHandle) {
            children.append(userMenu)
        }

        return UIMenu(children: children)
    }

    private func makeUserMenu(handle: String) -> UIMenu? {
        var userChildren: [UIMenuElement] = []

        if authManager.isAuthenticated,
           let relationship,
           !relationship.isViewer
        {
            var followAttributes: UIMenuElement.Attributes = []
            if isApplyingRelationshipAction {
                followAttributes.insert(.disabled)
            }

            let followAction = UIAction(
                title: relationship.viewerFollows
                    ? NSLocalizedString("sneakpeek.action.unfollow", comment: "Unfollow action")
                    : NSLocalizedString("sneakpeek.action.follow", comment: "Follow action"),
                image: UIImage(systemName: relationship.viewerFollows ? "person.badge.minus" : "person.badge.plus"),
                attributes: followAttributes
            ) { _ in
                performRelationshipAction(
                    relationship.viewerFollows ? .unfollow : .follow,
                    handle: handle
                )
            }
            userChildren.append(followAction)

            var blockAttributes: UIMenuElement.Attributes = []
            if isApplyingRelationshipAction {
                blockAttributes.insert(.disabled)
            }
            if !relationship.viewerBlocks {
                blockAttributes.insert(.destructive)
            }

            let blockAction = UIAction(
                title: relationship.viewerBlocks
                    ? NSLocalizedString("sneakpeek.action.unblock", comment: "Unblock action")
                    : NSLocalizedString("sneakpeek.action.block", comment: "Block action"),
                image: UIImage(systemName: relationship.viewerBlocks ? "nosign" : "hand.raised"),
                attributes: blockAttributes
            ) { _ in
                performRelationshipAction(
                    relationship.viewerBlocks ? .unblock : .block,
                    handle: handle
                )
            }
            userChildren.append(blockAction)
        }

        if let profileURL = actorProfileURL(handle: handle) {
            let shareProfileAction = UIAction(
                title: NSLocalizedString("sneakpeek.action.shareProfileLink", comment: "Share profile link"),
                image: UIImage(systemName: "link")
            ) { _ in
                ShareSheetPresenter.present(items: [profileURL])
            }
            userChildren.append(shareProfileAction)
        }

        guard !userChildren.isEmpty else { return nil }

        return UIMenu(
            title: NSLocalizedString("sneakpeek.menu.user", comment: "User menu"),
            image: UIImage(systemName: "person.crop.circle"),
            children: userChildren
        )
    }
}

private struct ProfileSneakPeekModifier: ViewModifier {
    let handle: String?
    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(ExternalURLRouter.self) private var externalURLRouter
    @State private var relationship: ActorRelationshipState?
    @State private var relationshipActionErrorMessage: String?
    @State private var isApplyingRelationshipAction = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if let handle {
            content
                .task(id: handle) {
                    await loadRelationship()
                }
                .uiContextMenu(
                    makeConfiguration: {
                        makeProfileContextMenuConfiguration(handle: handle)
                    },
                    onCommit: {
                        navigationCoordinator.navigateToProfile(handle: handle)
                    }
                )
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
        } else {
            content
        }
    }

    private func loadRelationship(cachePolicy: CachePolicy.Query.SingleResponse = .networkFirst) async {
        guard let handle else {
            relationship = nil
            return
        }

        do {
            relationship = try await ActorRelationshipService.fetch(handle: handle, cachePolicy: cachePolicy)
        } catch {
            relationship = nil
        }
    }

    private func performRelationshipAction(_ action: ActorRelationshipAction, handle: String) {
        guard authManager.isAuthenticated else { return }
        guard !isApplyingRelationshipAction else { return }

        Task {
            isApplyingRelationshipAction = true
            defer { isApplyingRelationshipAction = false }

            do {
                let currentRelationship: ActorRelationshipState
                if let relationship {
                    currentRelationship = relationship
                } else if let fetched = try await ActorRelationshipService.fetch(handle: handle, cachePolicy: .networkOnly) {
                    currentRelationship = fetched
                    self.relationship = fetched
                } else {
                    throw ActorRelationshipServiceError.actorNotFound
                }

                guard !currentRelationship.isViewer else { return }

                try await ActorRelationshipService.perform(action: action, actorId: currentRelationship.actorId)
                relationship = try await ActorRelationshipService.fetch(handle: handle, cachePolicy: .networkOnly)
            } catch {
                relationshipActionErrorMessage = error.localizedDescription
            }
        }
    }

    private func makeProfileContextMenuConfiguration(handle: String) -> UIContextMenuConfiguration {
        UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: {
                let preview = withPreviewEnvironment(
                    ActorProfileViewWrapper(handle: handle)
                        .frame(width: SneakPeekPreviewLayout.width, height: SneakPeekPreviewLayout.height)
                        .ignoresSafeArea(),
                    authManager: authManager,
                    navigationCoordinator: navigationCoordinator,
                    externalURLRouter: externalURLRouter
                )
                let controller = UIHostingController(rootView: preview)
                controller.view.backgroundColor = .systemBackground
                controller.view.insetsLayoutMarginsFromSafeArea = false
                controller.view.directionalLayoutMargins = .zero
                return controller
            },
            actionProvider: { _ in
                UIMenu(children: makeProfileContextActions(handle: handle))
            }
        )
    }

    private func makeProfileContextActions(handle: String) -> [UIMenuElement] {
        var actions: [UIMenuElement] = []

        if authManager.isAuthenticated,
           let relationship,
           !relationship.isViewer
        {
            var followAttributes: UIMenuElement.Attributes = []
            if isApplyingRelationshipAction {
                followAttributes.insert(.disabled)
            }

            let followAction = UIAction(
                title: relationship.viewerFollows
                    ? NSLocalizedString("sneakpeek.action.unfollow", comment: "Unfollow action")
                    : NSLocalizedString("sneakpeek.action.follow", comment: "Follow action"),
                image: UIImage(systemName: relationship.viewerFollows ? "person.badge.minus" : "person.badge.plus"),
                attributes: followAttributes
            ) { _ in
                performRelationshipAction(
                    relationship.viewerFollows ? .unfollow : .follow,
                    handle: handle
                )
            }
            actions.append(followAction)

            var blockAttributes: UIMenuElement.Attributes = []
            if isApplyingRelationshipAction {
                blockAttributes.insert(.disabled)
            }
            if !relationship.viewerBlocks {
                blockAttributes.insert(.destructive)
            }

            let blockAction = UIAction(
                title: relationship.viewerBlocks
                    ? NSLocalizedString("sneakpeek.action.unblock", comment: "Unblock action")
                    : NSLocalizedString("sneakpeek.action.block", comment: "Block action"),
                image: UIImage(systemName: relationship.viewerBlocks ? "nosign" : "hand.raised"),
                attributes: blockAttributes
            ) { _ in
                performRelationshipAction(
                    relationship.viewerBlocks ? .unblock : .block,
                    handle: handle
                )
            }
            actions.append(blockAction)
        }

        if let profileURL = actorProfileURL(handle: handle) {
            let shareProfileAction = UIAction(
                title: NSLocalizedString("sneakpeek.action.shareProfileLink", comment: "Share profile link"),
                image: UIImage(systemName: "link")
            ) { _ in
                ShareSheetPresenter.present(items: [profileURL])
            }
            actions.append(shareProfileAction)
        }

        return actions
    }
}

extension View {
    func postSneakPeek(postId: String?, actorHandle: String?, shareURL: URL? = nil) -> some View {
        modifier(PostSneakPeekModifier(postId: postId, actorHandle: actorHandle, shareURL: shareURL))
    }

    func profileSneakPeek(handle: String?) -> some View {
        modifier(ProfileSneakPeekModifier(handle: handle))
    }
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
    let enableProfileSneakPeek: Bool
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.2.squarepath")
                .font(.caption)

            HStack(spacing: 6) {
                KFImage(URL(string: actor.avatarUrl))
                    .placeholder {
                        Color.gray.opacity(0.2)
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())

                Group {
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
            }
            .contentShape(Rectangle())
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
                navigationCoordinator.navigateToProfile(handle: actor.handle)
            }
            .profileSneakPeek(handle: enableProfileSneakPeek ? actor.handle : nil)

            Text("reposted")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

private struct ActorHeaderIdentity<Actor: ActorProtocol>: View {
    let actor: Actor
    let avatarSize: CGFloat
    let nameFont: Font
    let nameWeight: Font.Weight?
    let handleFont: Font
    let sneakPeekHandle: String?

    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        HStack(spacing: 8) {
            KFImage(URL(string: actor.avatarUrl))
                .placeholder {
                    Color.gray.opacity(0.2)
                }
                .resizable()
                .scaledToFill()
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let name = actor.name {
                    let nameView = HTMLTextView(html: name, font: nameFont)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let nameWeight {
                        nameView.fontWeight(nameWeight)
                    } else {
                        nameView
                    }
                }
                Text(actor.handle)
                    .font(handleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 8)
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            navigationCoordinator.navigateToProfile(handle: actor.handle)
        }
        .profileSneakPeek(handle: sneakPeekHandle)
    }
}

struct QuotedPostCard<QuotedPost: QuotedPostProtocol>: View {
    let quotedPost: QuotedPost
    let disableNavigation: Bool
    let suppressContentLongPress: Bool
    let sneakPeekPostId: String?
    let sneakPeekActorHandle: String?
    let sneakPeekShareURL: URL?
    let enableProfileSneakPeek: Bool
    let showFullDateTime: Bool
    let onTap: (() -> Void)?

    init(
        quotedPost: QuotedPost,
        disableNavigation: Bool = false,
        suppressContentLongPress: Bool = false,
        sneakPeekPostId: String? = nil,
        sneakPeekActorHandle: String? = nil,
        sneakPeekShareURL: URL? = nil,
        enableProfileSneakPeek: Bool = false,
        showFullDateTime: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.quotedPost = quotedPost
        self.disableNavigation = disableNavigation
        self.suppressContentLongPress = suppressContentLongPress
        self.sneakPeekPostId = sneakPeekPostId
        self.sneakPeekActorHandle = sneakPeekActorHandle
        self.sneakPeekShareURL = sneakPeekShareURL
        self.enableProfileSneakPeek = enableProfileSneakPeek
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
                ActorHeaderIdentity(
                    actor: quotedPost.actor,
                    avatarSize: 32,
                    nameFont: .subheadline,
                    nameWeight: .semibold,
                    handleFont: .caption,
                    sneakPeekHandle: enableProfileSneakPeek ? quotedPost.actor.handle : nil
                )

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
                onTap: !disableNavigation ? onTap : nil,
                suppressLongPressInteractions: suppressContentLongPress,
                sneakPeekPostId: nil,
                sneakPeekActorHandle: nil,
                sneakPeekShareURL: nil
            )

            Text(publishedText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .postSneakPeek(
            postId: sneakPeekPostId,
            actorHandle: sneakPeekActorHandle,
            shareURL: sneakPeekShareURL
        )
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
    let enableSneakPeek: Bool
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager
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
    @AppStorage("engagement.sharePressActionsSwapped") private var sharePressActionsSwapped = false
    @AppStorage("engagement.quotePressActionsSwapped") private var quotePressActionsSwapped = false
    @AppStorage("engagement.confirmBeforeShare") private var confirmBeforeShare = false
    @AppStorage("engagement.confirmBeforeDelete") private var confirmBeforeDelete = true
    @State private var showingShareConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    @State private var markdownMaxLength = UserDefaults.standard.integer(forKey: "markdownMaxLength") {
        didSet {
            UserDefaults.standard.set(markdownMaxLength, forKey: "markdownMaxLength")
        }
    }

    init(
        post: P,
        showAuthor: Bool = true,
        disableNavigation: Bool = false,
        enableSneakPeek: Bool = false
    ) {
        self.post = post
        self.showAuthor = showAuthor
        self.disableNavigation = disableNavigation
        self.enableSneakPeek = enableSneakPeek
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

    private var canDeleteCurrentPost: Bool {
        guard let viewerHandle = authManager.currentAccount?.handle else { return false }
        let isViewerAuthor = viewerHandle.caseInsensitiveCompare(post.actor.handle) == .orderedSame
        return isViewerAuthor && post.sharedPost == nil
    }

    private var mainSneakPeekPostId: String? {
        guard sneakPeekEnabled, !post.isArticle else { return nil }
        return post.id
    }

    private var sneakPeekEnabled: Bool {
        enableSneakPeek && !disableNavigation
    }

    private func sneakPeekHandle(_ handle: String) -> String? {
        sneakPeekEnabled ? handle : nil
    }

    private func sneakPeekPostId(_ postId: String) -> String? {
        sneakPeekEnabled ? postId : nil
    }

    private func mediaItems<M: MediaProtocol>(from media: [M]) -> [MediaItem] {
        media.map {
            MediaItem(
                url: $0.url,
                thumbnailUrl: $0.thumbnailUrl,
                alt: $0.alt,
                width: $0.width,
                height: $0.height
            )
        }
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

    private func presentSharesSheet() {
        activeSheet = .shares
        Task {
            await fetchShares()
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
                mutation: HackersPub.DeletePostMutation(id: post.id)
            )

            if response.data?.deletePost.asDeletePostPayload != nil {
                NotificationCenter.default.post(name: Notification.Name("RefreshTimeline"), object: nil)
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
        guard canDeleteCurrentPost else { return }
        Task {
            await deletePost()
        }
    }

    private func requestDeletePost() {
        guard canDeleteCurrentPost else { return }
        if confirmBeforeDelete {
            showingDeleteConfirmation = true
        } else {
            performDeletePost()
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

    private func presentQuotesSheet() {
        activeSheet = .quotes
        Task {
            await fetchQuotes()
        }
    }

    private func presentQuoteComposer() {
        activeSheet = .quote
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
                VStack(alignment: .leading, spacing: 8) {
                    // Show repost indicator
                    if showAuthor && post.sharedPost != nil {
                        RepostIndicator(actor: post.actor, enableProfileSneakPeek: sneakPeekEnabled)
                    }

                    if showAuthor && post.sharedPost == nil {
                        HStack(spacing: 8) {
                            ActorHeaderIdentity(
                                actor: post.actor,
                                avatarSize: 40,
                                nameFont: .headline,
                                nameWeight: nil,
                                handleFont: .subheadline,
                                sneakPeekHandle: sneakPeekHandle(post.actor.handle)
                            )

                            Spacer()
                        }
                    }

                    if let sharedPost = post.sharedPost {
                        // Display shared post
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                ActorHeaderIdentity(
                                    actor: sharedPost.actor,
                                    avatarSize: 40,
                                    nameFont: .headline,
                                    nameWeight: nil,
                                    handleFont: .subheadline,
                                    sneakPeekHandle: sneakPeekHandle(sharedPost.actor.handle)
                                )

                                Spacer()
                            }

                            if let name = sharedPost.name {
                                Text(name)
                                    .font(.headline)
                            }

                            let content = self.getContent(content: sharedPost.content)
                            HTMLContentView(
                                html: content,
                                media: mediaItems(from: sharedPost.media),
                                onTap: !disableNavigation ? {
                                    navigationCoordinator.navigateToPost(id: sharedPost.id)
                                } : nil,
                                suppressLongPressInteractions: sneakPeekEnabled,
                                sneakPeekPostId: sneakPeekPostId(sharedPost.id),
                                sneakPeekActorHandle: sneakPeekHandle(sharedPost.actor.handle),
                                sneakPeekShareURL: sharedPost.resolvedShareURL
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
                            media: mediaItems(from: post.media),
                            onTap: !disableNavigation && !post.isArticle ? {
                                navigationCoordinator.navigateToPost(id: post.id)
                            } : nil,
                            suppressLongPressInteractions: sneakPeekEnabled,
                            sneakPeekPostId: mainSneakPeekPostId,
                            sneakPeekActorHandle: sneakPeekHandle(post.actor.handle),
                            sneakPeekShareURL: post.resolvedShareURL
                        )

                        if let quotedPost = post.quotedPost {
                            QuotedPostCard(
                                quotedPost: quotedPost,
                                disableNavigation: disableNavigation,
                                suppressContentLongPress: sneakPeekEnabled,
                                sneakPeekPostId: sneakPeekPostId(quotedPost.id),
                                sneakPeekActorHandle: sneakPeekHandle(quotedPost.actor.handle),
                                enableProfileSneakPeek: sneakPeekEnabled,
                                onTap: {
                                    navigationCoordinator.navigateToPost(id: quotedPost.id)
                                }
                            )
                        }
                    }

                    Text(DateFormatHelper.relativeTime(from: post.published))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    Group {
                        if !disableNavigation && !post.isArticle && !enableSneakPeek {
                            NavigationLink(destination: PostDetailView(postId: post.id)) {
                                Color.clear
                            }
                            .opacity(0)
                            .buttonStyle(.plain)
                        }
                    }
                )

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
                            handleShareTap()
                        },
                        onLongPress: {
                            handleShareLongPress()
                        }
                    )

                    EngagementToolbarButton(
                        icon: "quote.bubble",
                        count: post.engagementStats.quotes,
                        showsZeroCount: false,
                        onTap: {
                            handleQuoteTap()
                        },
                        onLongPress: {
                            handleQuoteLongPress()
                        }
                    )

                    Spacer()

                    if canDeleteCurrentPost {
                        Button {
                            requestDeletePost()
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

                    if let shareURL = post.resolvedShareURL {
                        ShareLink(item: shareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .foregroundStyle(.secondary)
            }
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
}
