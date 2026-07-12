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
    var viewerHasBookmarked: Bool { get }

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
    @State private var relationshipStateUpdateGate = ActorRelationshipStateUpdateGate()

    func body(content: Content) -> some View {
        if let postId {
            content
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
                .onChange(of: actorHandle) {
                    relationshipStateUpdateGate.invalidate()
                    relationship = nil
                    relationshipActionErrorMessage = nil
                }
        } else {
            content
        }
    }

    @MainActor
    private func loadRelationship(cachePolicy: CachePolicy.Query.SingleResponse = .networkFirst) async {
        guard let actorHandle else {
            relationshipStateUpdateGate.invalidate()
            relationship = nil
            return
        }
        let request = relationshipStateUpdateGate.begin(handle: actorHandle)

        do {
            let fetchedRelationship = try await ActorRelationshipService.fetch(
                handle: actorHandle,
                cachePolicy: cachePolicy
            )
            guard canApplyRelationshipStateUpdate(request) else { return }
            relationship = fetchedRelationship
        } catch {
            guard canApplyRelationshipStateUpdate(request) else { return }
        }
    }

    private func canApplyRelationshipStateUpdate(_ request: ActorRelationshipRequestToken) -> Bool {
        relationshipStateUpdateGate.allows(request, currentHandle: actorHandle)
    }

    private func performRelationshipAction(_ action: ActorRelationshipAction, handle: String) {
        guard authManager.isAuthenticated else { return }
        guard !isApplyingRelationshipAction else { return }

        let request = relationshipStateUpdateGate.begin(handle: handle)
        isApplyingRelationshipAction = true
        Task {
            defer { isApplyingRelationshipAction = false }

            do {
                let currentRelationship: ActorRelationshipState
                if let relationship, relationship.handle == handle {
                    currentRelationship = relationship
                } else if let fetched = try await ActorRelationshipService.fetch(
                    handle: handle,
                    cachePolicy: .networkOnly
                ) {
                    guard canApplyRelationshipStateUpdate(request) else { return }
                    currentRelationship = fetched
                    self.relationship = fetched
                } else {
                    throw ActorRelationshipServiceError.actorNotFound
                }

                guard !currentRelationship.isViewer else { return }

                try await ActorRelationshipService.perform(action: action, actorId: currentRelationship.actorId)
                let refreshedRelationship = try await ActorRelationshipService.fetch(
                    handle: handle,
                    cachePolicy: .networkOnly
                )
                guard canApplyRelationshipStateUpdate(request) else { return }
                relationship = refreshedRelationship
            } catch {
                guard canApplyRelationshipStateUpdate(request) else { return }
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
                presentShareSheet(items: [shareURL])
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

        if authManager.isAuthenticated {
            userChildren.append(
                UIDeferredMenuElement { completion in
                    DeferredMenuMainActor.perform {
                        await loadRelationship()
                        let actions = relationshipActions(handle: handle)
                        completion(actions)
                    }
                }
            )
        }

        if let profileURL = actorProfileURL(handle: handle) {
            let shareProfileAction = UIAction(
                title: NSLocalizedString("sneakpeek.action.shareProfileLink", comment: "Share profile link"),
                image: UIImage(systemName: "link")
            ) { _ in
                presentShareSheet(items: [profileURL])
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

    private func presentShareSheet(items: [Any]) {
        Task { @MainActor in
            if let error = await ShareSheetPresentationCaller.shared.present(items: items) {
                relationshipActionErrorMessage = error.userFacingMessage
            }
        }
    }

    @MainActor
    private func relationshipActions(handle: String) -> [UIMenuElement] {
        guard authManager.isAuthenticated,
              let relationship,
              !relationship.isViewer
        else {
            return []
        }

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

        return [followAction, blockAction]
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
    @State private var relationshipStateUpdateGate = ActorRelationshipStateUpdateGate()

    func body(content: Content) -> some View {
        if let handle {
            content
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
                .onChange(of: handle) {
                    relationshipStateUpdateGate.invalidate()
                    relationship = nil
                    relationshipActionErrorMessage = nil
                }
        } else {
            content
        }
    }

    @MainActor
    private func loadRelationship(cachePolicy: CachePolicy.Query.SingleResponse = .networkFirst) async {
        guard let handle else {
            relationshipStateUpdateGate.invalidate()
            relationship = nil
            return
        }
        let request = relationshipStateUpdateGate.begin(handle: handle)

        do {
            let fetchedRelationship = try await ActorRelationshipService.fetch(
                handle: handle,
                cachePolicy: cachePolicy
            )
            guard canApplyRelationshipStateUpdate(request) else { return }
            relationship = fetchedRelationship
        } catch {
            guard canApplyRelationshipStateUpdate(request) else { return }
        }
    }

    private func canApplyRelationshipStateUpdate(_ request: ActorRelationshipRequestToken) -> Bool {
        relationshipStateUpdateGate.allows(request, currentHandle: handle)
    }

    private func performRelationshipAction(_ action: ActorRelationshipAction, handle: String) {
        guard authManager.isAuthenticated else { return }
        guard !isApplyingRelationshipAction else { return }

        let request = relationshipStateUpdateGate.begin(handle: handle)
        isApplyingRelationshipAction = true
        Task {
            defer { isApplyingRelationshipAction = false }

            do {
                let currentRelationship: ActorRelationshipState
                if let relationship, relationship.handle == handle {
                    currentRelationship = relationship
                } else if let fetched = try await ActorRelationshipService.fetch(
                    handle: handle,
                    cachePolicy: .networkOnly
                ) {
                    guard canApplyRelationshipStateUpdate(request) else { return }
                    currentRelationship = fetched
                    self.relationship = fetched
                } else {
                    throw ActorRelationshipServiceError.actorNotFound
                }

                guard !currentRelationship.isViewer else { return }

                try await ActorRelationshipService.perform(action: action, actorId: currentRelationship.actorId)
                let refreshedRelationship = try await ActorRelationshipService.fetch(
                    handle: handle,
                    cachePolicy: .networkOnly
                )
                guard canApplyRelationshipStateUpdate(request) else { return }
                relationship = refreshedRelationship
            } catch {
                guard canApplyRelationshipStateUpdate(request) else { return }
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

        if authManager.isAuthenticated {
            actions.append(
                UIDeferredMenuElement { completion in
                    DeferredMenuMainActor.perform {
                        await loadRelationship()
                        let elements = profileRelationshipActions(handle: handle)
                        completion(elements)
                    }
                }
            )
        }

        if let profileURL = actorProfileURL(handle: handle) {
            let shareProfileAction = UIAction(
                title: NSLocalizedString("sneakpeek.action.shareProfileLink", comment: "Share profile link"),
                image: UIImage(systemName: "link")
            ) { _ in
                presentShareSheet(items: [profileURL])
            }
            actions.append(shareProfileAction)
        }

        return actions
    }

    private func presentShareSheet(items: [Any]) {
        Task { @MainActor in
            if let error = await ShareSheetPresentationCaller.shared.present(items: items) {
                relationshipActionErrorMessage = error.userFacingMessage
            }
        }
    }

    @MainActor
    private func profileRelationshipActions(handle: String) -> [UIMenuElement] {
        guard authManager.isAuthenticated,
              let relationship,
              !relationship.isViewer
        else {
            return []
        }

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

        return [followAction, blockAction]
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

private struct EngagementToolbarAlternateAction: ViewModifier {
    let name: String?
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let name, let action {
            content.accessibilityAction(named: Text(name)) {
                action()
            }
        } else {
            content
        }
    }
}

struct EngagementToolbarButton: View {
    let icon: String
    let count: Int
    let showsZeroCount: Bool
    let accessibility: EngagementToolbarAccessibility
    let tint: Color
    let isLoading: Bool
    let onTap: () -> Void
    let onLongPress: (() -> Void)?

    init(
        icon: String,
        count: Int,
        showsZeroCount: Bool,
        accessibilityLabel: String,
        accessibilityLongPressLabel: String? = nil,
        tint: Color = .secondary,
        isLoading: Bool = false,
        onTap: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.count = count
        self.showsZeroCount = showsZeroCount
        accessibility = EngagementToolbarAccessibility(
            label: accessibilityLabel,
            count: count,
            alternateActionName: accessibilityLongPressLabel
        )
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
        .frame(
            minWidth: CGFloat(EngagementToolbarAccessibility.minimumHitSize),
            minHeight: CGFloat(EngagementToolbarAccessibility.minimumHitSize)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibility.label)
        .accessibilityValue(accessibility.value)
        .accessibilityAction {
            EngagementToolbarGesturePolicy.dispatch(
                .tap,
                onTap: onTap,
                onLongPress: onLongPress
            )
        }
        .modifier(
            EngagementToolbarAlternateAction(
                name: accessibility.alternateActionName,
                action: onLongPress
            )
        )
        .gesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    EngagementToolbarGesturePolicy.dispatch(
                        .longPress,
                        onTap: onTap,
                        onLongPress: onLongPress
                    )
                }
                .exclusively(
                    before: TapGesture()
                        .onEnded {
                            EngagementToolbarGesturePolicy.dispatch(
                                .tap,
                                onTap: onTap,
                                onLongPress: onLongPress
                            )
                        }
                )
        )
    }
}

struct RepostIndicator: View {
    let actor: any ActorProtocol
    let enableProfileSneakPeek: Bool
    let prefersPlainTextName: Bool
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(
        actor: any ActorProtocol,
        enableProfileSneakPeek: Bool,
        prefersPlainTextName: Bool = false
    ) {
        self.actor = actor
        self.enableProfileSneakPeek = enableProfileSneakPeek
        self.prefersPlainTextName = prefersPlainTextName
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.2.squarepath")
                .font(.caption)

            HStack(spacing: 6) {
                KFImage(URL(string: actor.avatarUrl))
                    .placeholder {
                        Color.gray.opacity(0.2)
                    }
                    .downsampling(size: CGSize(width: 32, height: 32))
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())

                Group {
                    if let name = actor.name {
                        if prefersPlainTextName {
                            Text(plainTextPreview(from: name))
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            HTMLTextView(html: name, font: .caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
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

            Text(PostL10n.reposted)
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
    let prefersPlainTextName: Bool

    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(
        actor: Actor,
        avatarSize: CGFloat,
        nameFont: Font,
        nameWeight: Font.Weight?,
        handleFont: Font,
        sneakPeekHandle: String?,
        prefersPlainTextName: Bool = false
    ) {
        self.actor = actor
        self.avatarSize = avatarSize
        self.nameFont = nameFont
        self.nameWeight = nameWeight
        self.handleFont = handleFont
        self.sneakPeekHandle = sneakPeekHandle
        self.prefersPlainTextName = prefersPlainTextName
    }

    var body: some View {
        HStack(spacing: 8) {
            KFImage(URL(string: actor.avatarUrl))
                .placeholder {
                    Color.gray.opacity(0.2)
                }
                .downsampling(
                    size: CGSize(
                        width: avatarSize * UIScreen.main.scale,
                        height: avatarSize * UIScreen.main.scale
                    )
                )
                .cancelOnDisappear(true)
                .resizable()
                .scaledToFill()
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let name = actor.name {
                    let nameView = Group {
                        if prefersPlainTextName {
                            Text(plainTextPreview(from: name))
                        } else {
                            HTMLTextView(html: name, font: nameFont)
                        }
                    }
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

private func plainTextPreview(from html: String) -> String {
    var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "&nbsp;", with: " ")
    text = text.replacingOccurrences(of: "&amp;", with: "&")
    text = text.replacingOccurrences(of: "&lt;", with: "<")
    text = text.replacingOccurrences(of: "&gt;", with: ">")
    text = text.replacingOccurrences(of: "&quot;", with: "\"")
    text = text.replacingOccurrences(of: "&#39;", with: "'")
    text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

struct QuotedPostCard<QuotedPost: QuotedPostProtocol>: View {
    let quotedPost: QuotedPost
    let contentRenderMode: HTMLContentRenderMode
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
        contentRenderMode: HTMLContentRenderMode = .richWebView,
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
        self.contentRenderMode = contentRenderMode
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
                    nameWeight: .bold,
                    handleFont: .caption,
                    sneakPeekHandle: enableProfileSneakPeek ? quotedPost.actor.handle : nil,
                    prefersPlainTextName: contentRenderMode == .lightweightText
                )

                Spacer()
            }

            if let name = quotedPost.name {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            EmbeddedPostContentPreviewView(
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
                sneakPeekPostId: sneakPeekPostId,
                sneakPeekActorHandle: sneakPeekActorHandle,
                sneakPeekShareURL: sneakPeekShareURL
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
    let timelineSharer: (any ActorProtocol)?
    let timelineAdded: String?
    let showAuthor: Bool
    let disableNavigation: Bool
    let enableSneakPeek: Bool
    let contentRenderMode: HTMLContentRenderMode
    let onBookmarkChanged: ((String, Bool) -> Void)?
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var activeSheet: ActiveSheet?
    @State private var pendingQuotedPostNavigation = PendingSheetPostNavigation()
    @State private var showingReactionPicker = false
    @State private var isBookmarking = false
    @State private var isReacting = false
    @State private var engagementState: PostEngagementState
    @State private var reactionInfoState = ReactionInfoLoadState<ReactionGroupInfo>()
    @State private var reactionRetryEmoji: String?
    @State private var reactionCoordinator: PostReactionRequestCoordinator
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
    @AppStorage(MarkdownMaxLengthPreference.key)
    private var markdownMaxLength = MarkdownMaxLengthPreference.defaultValue

    init(
        post: P,
        timelineSharer: (any ActorProtocol)? = nil,
        timelineAdded: String? = nil,
        showAuthor: Bool = true,
        disableNavigation: Bool = false,
        enableSneakPeek: Bool = false,
        contentRenderMode: HTMLContentRenderMode = .richWebView,
        onBookmarkChanged: ((String, Bool) -> Void)? = nil
    ) {
        self.post = post
        self.timelineSharer = timelineSharer
        self.timelineAdded = timelineAdded
        self.showAuthor = showAuthor
        self.disableNavigation = disableNavigation
        self.enableSneakPeek = enableSneakPeek
        self.contentRenderMode = contentRenderMode
        self.onBookmarkChanged = onBookmarkChanged
        let engagementState = PostEngagementState(post: post)
        _engagementState = State(initialValue: engagementState)
        _reactionCoordinator = State(
            initialValue: PostReactionRequestCoordinator(targetPostID: engagementState.target.postID)
        )
        _sharesState = State(initialValue: Self.makeSharesState(postID: engagementState.target.postID))
        _quotesState = State(initialValue: Self.makeQuotesState(postID: engagementState.target.postID))
    }

    private static func makeSharesState(postID: String) -> EngagementListSheetState<ShareActorInfo> {
        EngagementListSheetState(id: \.id, loader: sharesLoader(for: postID))
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
        engagementState.viewerHasReacted
    }

    private var incomingEngagementState: PostEngagementState {
        PostEngagementState(post: post)
    }

    private var canDeleteCurrentPost: Bool {
        guard let viewerHandle = authManager.currentAccount?.handle else { return false }
        let isViewerAuthor = viewerHandle.caseInsensitiveCompare(post.actor.handle) == .orderedSame
        return isViewerAuthor && post.sharedPost == nil && timelineSharer == nil
    }

    private var canPerformEngagementActions: Bool {
        authManager.isAuthenticated
    }

    private var engagementTargetID: String {
        engagementState.target.postID
    }

    private var bookmarkTargetID: String {
        engagementTargetID
    }

    private var repostIndicatorActor: (any ActorProtocol)? {
        timelineSharer ?? (post.sharedPost == nil ? nil : post.actor)
    }

    private var displayedPublished: String {
        timelineAdded ?? post.published
    }

    private var mainSneakPeekPostId: String? {
        guard sneakPeekEnabled, !post.isArticle else { return nil }
        return engagementTargetID
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
                id: $0.url,
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
        guard let attempt = engagementState.beginShareToggle() else { return }

        do {
            let result = try await PostEngagementMutationService.setShared(
                postID: attempt.targetPostID,
                desiredHasShared: attempt.desiredHasShared
            )
            engagementState.completeShare(
                attempt,
                hasShared: result.hasShared,
                sharesCount: result.sharesCount
            )
        } catch {
            if PostEngagementMutationError.isCancellation(error) {
                engagementState.cancelShare(attempt)
            } else {
                engagementState.failShare(
                    attempt,
                    message: PostEngagementMutationError.userMessage(for: error)
                )
            }
        }
    }

    private func toggleBookmark() async {
        guard !isBookmarking else { return }
        guard AuthManager.shared.currentAccount != nil else { return }

        isBookmarking = true
        let previousState = engagementState.hasBookmarked
        engagementState.hasBookmarked.toggle()
        defer { isBookmarking = false }

        do {
            if previousState {
                let response = try await apolloClient.perform(
                    mutation: HackersPub.UnbookmarkPostMutation(postId: bookmarkTargetID)
                )
                if let payload = response.data?.unbookmarkPost.asUnbookmarkPostPayload {
                    engagementState.hasBookmarked = PostBookmarkChangePropagation.resolve(
                        postID: bookmarkTargetID,
                        authoritativeState: payload.post.viewerHasBookmarked,
                        fallbackState: previousState,
                        onChange: onBookmarkChanged
                    )
                } else {
                    engagementState.hasBookmarked = previousState
                }
            } else {
                let response = try await apolloClient.perform(
                    mutation: HackersPub.BookmarkPostMutation(postId: bookmarkTargetID)
                )
                if let payload = response.data?.bookmarkPost.asBookmarkPostPayload {
                    engagementState.hasBookmarked = PostBookmarkChangePropagation.resolve(
                        postID: bookmarkTargetID,
                        authoritativeState: payload.post.viewerHasBookmarked,
                        fallbackState: previousState,
                        onChange: onBookmarkChanged
                    )
                } else {
                    engagementState.hasBookmarked = previousState
                }
            }
        } catch {
            engagementState.hasBookmarked = previousState
            print("Error toggling bookmark: \(error)")
        }
    }

    private func presentSharesSheet() {
        activeSheet = .shares
        Task {
            await sharesState.reload()
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
                mutation: HackersPub.DeletePostMutation(id: post.id)
            )

            if response.data?.deletePost.asDeletePostPayload != nil {
                PostContentEventCenter.publish(.postDeleted(postID: post.id))
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

    private func presentQuotesSheet() {
        activeSheet = .quotes
        Task {
            await quotesState.reload()
        }
    }

    private func presentQuoteComposer() {
        guard AuthManager.shared.currentAccount != nil else {
            presentQuotesSheet()
            return
        }
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

    private func presentReactionPicker() {
        engagementState.prepareReactionPicker()
        reactionRetryEmoji = nil
        if useReactionPopover {
            showingReactionPicker = true
        } else {
            activeSheet = .reactionPicker
        }

        Task {
            await fetchReactionInfos()
        }
    }

    private func applyReactionLocally(emoji: String, add: Bool) {
        engagementState.applyReaction(emoji: emoji, adding: add)
    }

    private func fetchReactionInfos() async {
        guard reactionInfoState.beginLoading() else { return }
        reactionCoordinator.setTargetPostID(engagementTargetID)
        guard let request = reactionCoordinator.beginInfoLoad() else { return }

        do {
            let result = try await PostReactionInfoService.fetch(postID: request.targetPostID)
            guard reactionCoordinator.shouldApply(request) else { return }
            reactionInfoState.succeed(items: result.infos)
            engagementState.reconcileReactions(groups: result.groups, totalCount: result.totalCount)
        } catch {
            guard reactionCoordinator.shouldApply(request) else { return }
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

    // swiftlint:disable:next function_body_length
    private func toggleReaction(emoji: String) async -> PostReactionMutationResult? {
        guard !isReacting else { return nil }
        guard AuthManager.shared.currentAccount != nil else {
            engagementState.reactionErrorMessage = ReactionL10n.signInRequired
            reactionRetryEmoji = emoji
            return nil
        }
        isReacting = true
        defer { isReacting = false }

        reactionCoordinator.setTargetPostID(engagementTargetID)
        guard let attempt = reactionCoordinator.beginMutation() else { return nil }
        reactionInfoState.cancel()
        let rollback = engagementState.reactionRollbackSnapshot()

        let shouldRemove = ReactionGroupIndex.viewerHasReacted(
            to: emoji,
            in: engagementState.reactionGroups
        )
        let mutationEmoji = shouldRemove
            ? ReactionGroupIndex.mutationEmoji(for: emoji, in: engagementState.reactionGroups)
            : emoji
        applyReactionLocally(emoji: mutationEmoji, add: !shouldRemove)

        do {
            let result = try await PostEngagementMutationService.setReaction(
                postID: attempt.targetPostID,
                emoji: mutationEmoji,
                adding: !shouldRemove
            )
            reactionRetryEmoji = nil
            switch reactionCoordinator.finish(attempt, outcome: .success) {
            case .synchronize:
                return result
            case .ignore, .rollbackWithoutError, .rollbackWithError:
                return nil
            }
        } catch {
            let completion = reactionCoordinator.finish(
                attempt,
                outcome: PostEngagementMutationError.isCancellation(error) ? .cancelled : .failure
            )
            switch completion {
            case .rollbackWithoutError:
                engagementState.restoreReactionState(from: rollback)
            case .rollbackWithError:
                engagementState.restoreReactionState(from: rollback)
                engagementState.reactionErrorMessage = PostReactionMutationError.userMessage(
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

    private func openQuotedPost(id: String) {
        pendingQuotedPostNavigation.schedule(postID: id)
        activeSheet = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                // Show repost indicator
                if showAuthor, let repostIndicatorActor {
                    RepostIndicator(
                        actor: repostIndicatorActor,
                        enableProfileSneakPeek: sneakPeekEnabled,
                        prefersPlainTextName: contentRenderMode == .lightweightText
                    )
                }

                if showAuthor && post.sharedPost == nil && timelineSharer == nil {
                    HStack(spacing: 8) {
                        ActorHeaderIdentity(
                            actor: post.actor,
                            avatarSize: 40,
                            nameFont: .headline,
                            nameWeight: .bold,
                            handleFont: .subheadline,
                            sneakPeekHandle: sneakPeekHandle(post.actor.handle),
                            prefersPlainTextName: contentRenderMode == .lightweightText
                        )

                        Spacer()
                    }
                }

                if timelineSharer != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            ActorHeaderIdentity(
                                actor: post.actor,
                                avatarSize: 40,
                                nameFont: .headline,
                                nameWeight: .bold,
                                handleFont: .subheadline,
                                sneakPeekHandle: sneakPeekHandle(post.actor.handle),
                                prefersPlainTextName: contentRenderMode == .lightweightText
                            )

                            Spacer()
                        }

                        if let name = post.name {
                            Text(name)
                                .font(.headline)
                        }

                        let content = self.getContent(content: post.content)
                        EmbeddedPostContentPreviewView(
                            html: content,
                            media: mediaItems(from: post.media),
                            onTap: !disableNavigation ? {
                                navigationCoordinator.navigateToPost(id: post.id)
                            } : nil,
                            suppressLongPressInteractions: sneakPeekEnabled,
                            sneakPeekPostId: sneakPeekPostId(post.id),
                            sneakPeekActorHandle: sneakPeekHandle(post.actor.handle),
                            sneakPeekShareURL: post.resolvedShareURL
                        )

                        if let quotedPost = post.quotedPost {
                            QuotedPostCard(
                                quotedPost: quotedPost,
                                contentRenderMode: contentRenderMode,
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

                        Text(DateFormatHelper.relativeTime(from: post.published))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let sharedPost = post.sharedPost {
                    // Display shared post
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            ActorHeaderIdentity(
                                actor: sharedPost.actor,
                                avatarSize: 40,
                                nameFont: .headline,
                                nameWeight: .bold,
                                handleFont: .subheadline,
                                sneakPeekHandle: sneakPeekHandle(sharedPost.actor.handle),
                                prefersPlainTextName: contentRenderMode == .lightweightText
                            )

                            Spacer()
                        }

                        if let name = sharedPost.name {
                            Text(name)
                                .font(.headline)
                        }

                        let content = self.getContent(content: sharedPost.content)
                        EmbeddedPostContentPreviewView(
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

                        if let quotedPost = sharedPost.quotedPost {
                            QuotedPostCard(
                                quotedPost: quotedPost,
                                contentRenderMode: contentRenderMode,
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

                        Text(DateFormatHelper.relativeTime(from: sharedPost.published))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if post.isArticle {
                    ArticleSummaryCard(post: post) {
                        navigationCoordinator.navigateToPost(id: post.id)
                    }
                } else {
                    // Display original post content
                    if let name = post.name {
                        Text(name)
                            .font(.headline)
                    }

                    let content = self.getContent(content: post.content)
                    PostContentPreviewView(
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
                            contentRenderMode: contentRenderMode,
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

                Text(DateFormatHelper.relativeTime(from: displayedPublished))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                Group {
                    if !disableNavigation && !post.isArticle && !enableSneakPeek {
                        NavigationLink(destination: PostDetailView(postId: engagementTargetID)) {
                            Color.clear
                        }
                        .opacity(0)
                        .buttonStyle(.plain)
                    }
                }
            )

            HStack(spacing: 16) {
                EngagementToolbarButton(
                    icon: "arrowshape.turn.up.left",
                    count: engagementState.repliesCount,
                    showsZeroCount: false,
                    accessibilityLabel: canPerformEngagementActions
                        ? PostL10n.repliesTitle
                        : PostL10n.viewRepliesAction,
                    onTap: {
                        if canPerformEngagementActions {
                            activeSheet = .reply
                        } else {
                            navigationCoordinator.navigateToPost(id: engagementTargetID)
                        }
                    }
                )

                EngagementToolbarButton(
                    icon: "arrow.2.squarepath",
                    count: engagementState.sharesCount,
                    showsZeroCount: false,
                    accessibilityLabel: canPerformEngagementActions
                        ? PostL10n.sharesTitle
                        : PostL10n.viewSharesAction,
                    accessibilityLongPressLabel: canPerformEngagementActions
                        ? (sharePressActionsSwapped
                            ? (engagementState.hasShared ? PostL10n.unshareAction : PostL10n.shareAction)
                            : PostL10n.viewSharesAction)
                        : PostL10n.viewSharesAction,
                    tint: engagementState.hasShared ? .green : .secondary,
                    isLoading: engagementState.isSharing,
                    onTap: {
                        handleShareTap()
                    },
                    onLongPress: {
                        handleShareLongPress()
                    }
                )

                EngagementToolbarButton(
                    icon: viewerHasReacted ? "heart.fill" : "heart",
                    count: engagementState.reactionsCount,
                    showsZeroCount: false,
                    accessibilityLabel: ReactionL10n.title,
                    tint: viewerHasReacted ? .red : .secondary,
                    isLoading: isReacting,
                    onTap: {
                        presentReactionPicker()
                    }
                )

                EngagementToolbarButton(
                    icon: "quote.bubble",
                    count: engagementState.quotesCount,
                    showsZeroCount: false,
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
                            Image(systemName: engagementState.hasBookmarked ? "bookmark.fill" : "bookmark")
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(engagementState.hasBookmarked ? .yellow : .secondary)
                    .accessibilityLabel(
                        engagementState.hasBookmarked
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
            }
            .foregroundStyle(.secondary)
        }
        .onChange(of: post.id) {
            engagementState = incomingEngagementState
            reactionInfoState = ReactionInfoLoadState()
            reactionRetryEmoji = nil
            reactionCoordinator = PostReactionRequestCoordinator(targetPostID: engagementTargetID)
            sharesState.reset(loader: Self.sharesLoader(for: engagementTargetID))
            quotesState.reset(loader: Self.quotesLoader(for: engagementTargetID))
        }
        .onChange(of: incomingEngagementState) { _, incomingState in
            engagementState = incomingState
            reactionInfoState = ReactionInfoLoadState()
            reactionRetryEmoji = nil
            reactionCoordinator = PostReactionRequestCoordinator(targetPostID: incomingState.target.postID)
            sharesState.reset(loader: Self.sharesLoader(for: incomingState.target.postID))
            quotesState.reset(loader: Self.quotesLoader(for: incomingState.target.postID))
        }
        .sheet(
            item: $activeSheet,
            onDismiss: {
                if let postID = pendingQuotedPostNavigation.consume() {
                    navigationCoordinator.navigateToPost(id: postID)
                }
            },
            content: { sheet in
                switch sheet {
                case .reply:
                    ComposeView(
                        replyToPostId: engagementTargetID
                    )
                case .quote:
                    ComposeView(quotedPostId: engagementTargetID)
                case .shares:
                    SharesListSheetView(
                        title: PostEngagementSheetL10n.sharesTitle,
                        state: sharesState,
                        emptyTitle: PostEngagementSheetL10n.sharesEmpty,
                        loadMoreTitle: PostEngagementSheetL10n.sharesLoadMore
                    )
                case .quotes:
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
                        reactionGroups: engagementState.reactionGroups,
                        reactionInfos: reactionInfoState.items,
                        isLoadingReactionInfos: reactionInfoState.isLoading,
                        reactionInfosErrorMessage: reactionInfoState.errorMessage,
                        reactionMutationErrorMessage: engagementState.reactionErrorMessage,
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
                }
            }
        )
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
                reactionGroups: engagementState.reactionGroups,
                reactionInfos: reactionInfoState.items,
                isLoadingReactionInfos: reactionInfoState.isLoading,
                reactionInfosErrorMessage: reactionInfoState.errorMessage,
                reactionMutationErrorMessage: engagementState.reactionErrorMessage,
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
                get: { engagementState.shareErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        engagementState.shareErrorMessage = nil
                    }
                }
            )
        ) {
            Button(NSLocalizedString("common.retry", comment: "Retry")) {
                performShareToggle()
            }
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {
                engagementState.shareErrorMessage = nil
            }
        } message: {
            Text(engagementState.shareErrorMessage ?? "")
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
            engagementState.hasShared
                ? NSLocalizedString("share.confirm.unshareTitle", comment: "Confirmation dialog title for undoing a share")
                : NSLocalizedString("share.confirm.shareTitle", comment: "Confirmation dialog title for sharing a post"),
            isPresented: $showingShareConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                engagementState.hasShared
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
