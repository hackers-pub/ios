import SwiftUI
import Kingfisher
@preconcurrency import Apollo

typealias NotificationItem = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node
typealias NotificationEdge = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge

protocol NotificationActorProtocol {
    var id: String { get }
    var name: String? { get }
    var handle: String { get }
    var avatarUrl: String { get }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.Actors.Edge.Node: NotificationActorProtocol {}

struct NotificationsView: View {
    @State private var notifications: [NotificationEdge] = []
    @State private var hasLoadedInitial = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasPreviousPage = false
    @State private var hasNextPage = false
    @State private var startCursor: String?
    @State private var endCursor: String?
    @State private var pendingNewerCursor: String?
    @State private var pendingNewerInsertionIndex: Int?
    @State private var pendingNewerUsesBackwardPagination = false
    @State private var showingSettings = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .notifications)) {
            Group {
                if isLoading && notifications.isEmpty {
                    ProgressView()
                } else if let errorMessage, notifications.isEmpty {
                    LoadFailureView(message: errorMessage) {
                        Task {
                            await fetchNotifications()
                        }
                    }
                } else if notifications.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("notifications.empty.title", comment: "No notifications title"),
                        systemImage: "bell.slash",
                        description: Text(NSLocalizedString("notifications.empty.description", comment: "No notifications description"))
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if hasPreviousPage && !notifications.isEmpty {
                                LoadNewerItemsRow(isLoading: isLoading) {
                                    Task {
                                        await loadNewerNotifications()
                                    }
                                }
                                Divider()
                            }

                            ForEach(notifications, id: \.node.id) { notification in
                                NotificationRowView(notification: notification.node)
                                    .padding()
                                    .id(notification.node.id)
                                    .onAppear {
                                        if notification.node.id == notifications.last?.node.id && hasNextPage && !isLoading {
                                            Task {
                                                await loadMore()
                                            }
                                        }
                                    }

                                Divider()
                            }

                            if isLoading && !notifications.isEmpty {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding()
                            }

                            if let errorMessage, !notifications.isEmpty {
                                InlineLoadFailureView(message: errorMessage) {
                                    Task {
                                        await refreshNotifications()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav.notifications", comment: "Notifications navigation title"))
            .refreshable {
                await refreshNotifications()
            }
            .task {
                guard !hasLoadedInitial else { return }
                hasLoadedInitial = true
                await fetchNotifications()
            }
            .onChange(of: navigationCoordinator.currentTab) { _, newValue in
                guard newValue == .notifications, hasLoadedInitial, !isLoading else { return }
                Task {
                    await refreshNotifications()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ViewerProfileButton()
                }

                ToolbarItem(placement: .navigation) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label(NSLocalizedString("common.settings", comment: "Settings button"), systemImage: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .profile(let handle):
                    ActorProfileViewWrapper(handle: handle)
                case .post(let id):
                    PostDetailView(postId: id)
                case .newsStory(let id):
                    NewsStoryDetailView(storyId: id)
                }
            }
        }
    }

    private func fetchNotifications() async {
        // Don't show loading initially if we have cached data
        if notifications.isEmpty {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.NotificationsQuery(after: nil, before: nil, first: 20, last: nil),
                cachePolicy: .networkFirst
            )

            notifications = response.data?.viewer?.notifications.edges ?? []
            hasPreviousPage = response.data?.viewer?.notifications.pageInfo.hasPreviousPage ?? false
            pendingNewerCursor = nil
            pendingNewerInsertionIndex = nil
            pendingNewerUsesBackwardPagination = false
            hasNextPage = response.data?.viewer?.notifications.pageInfo.hasNextPage ?? false
            startCursor = response.data?.viewer?.notifications.pageInfo.startCursor
            endCursor = response.data?.viewer?.notifications.pageInfo.endCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.NotificationsQuery(after: .some(cursor), before: nil, first: 20, last: nil),
                cachePolicy: .networkOnly
            )
            appendUnique(response.data?.viewer?.notifications.edges ?? [])
            hasNextPage = response.data?.viewer?.notifications.pageInfo.hasNextPage ?? false
            endCursor = response.data?.viewer?.notifications.pageInfo.endCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshNotifications() async {
        let shouldShowLoading = notifications.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        defer {
            if shouldShowLoading {
                isLoading = false
            }
        }

        do {
            if notifications.isEmpty || startCursor == nil {
                let response = try await apolloClient.fetch(
                    query: HackersPub.NotificationsQuery(after: nil, before: nil, first: 20, last: nil),
                    cachePolicy: .networkOnly
                )
                notifications = response.data?.viewer?.notifications.edges ?? []
                hasPreviousPage = response.data?.viewer?.notifications.pageInfo.hasPreviousPage ?? false
                pendingNewerCursor = nil
                pendingNewerInsertionIndex = nil
                pendingNewerUsesBackwardPagination = false
                hasNextPage = response.data?.viewer?.notifications.pageInfo.hasNextPage ?? false
                startCursor = response.data?.viewer?.notifications.pageInfo.startCursor
                endCursor = response.data?.viewer?.notifications.pageInfo.endCursor
            } else {
                try await fetchNewerNotifications()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadNewerNotifications() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await fetchNewerNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchNewerNotifications() async throws {
        if pendingNewerUsesBackwardPagination,
           let cursor = pendingNewerCursor ?? startCursor
        {
            do {
                let response = try await apolloClient.fetch(
                    query: HackersPub.NotificationsQuery(after: nil, before: .some(cursor), first: nil, last: 20),
                    cachePolicy: .networkOnly
                )
                guard let connection = response.data?.viewer?.notifications else {
                    if pendingNewerUsesBackwardPagination {
                        return
                    }
                    throw CancellationError()
                }
                mergeNewerPage(
                    connection.edges,
                    nextCursor: connection.pageInfo.endCursor,
                    hasNextPage: connection.pageInfo.hasPreviousPage,
                    usesBackwardPagination: true
                )
                if let newStartCursor = notifications.first?.cursor {
                    startCursor = newStartCursor
                }
                if endCursor == nil {
                    endCursor = connection.pageInfo.endCursor
                }
                return
            } catch {
                if pendingNewerUsesBackwardPagination, !(error is CancellationError) {
                    throw error
                }
            }
        }

        let response = try await apolloClient.fetch(
            query: HackersPub.NotificationsQuery(
                after: pendingNewerCursor.map { .some($0) } ?? nil,
                before: nil,
                first: 20,
                last: nil
            ),
            cachePolicy: .networkOnly
        )
        let connection = response.data?.viewer?.notifications
        mergeNewerPage(
            connection?.edges ?? [],
            nextCursor: connection?.pageInfo.endCursor,
            hasNextPage: connection?.pageInfo.hasNextPage ?? false,
            usesBackwardPagination: false
        )
        if let newStartCursor = notifications.first?.cursor {
            startCursor = newStartCursor
        }
        if endCursor == nil {
            endCursor = connection?.pageInfo.endCursor
        }
    }

    private func prependUnique(_ incoming: [NotificationEdge]) {
        let existingIDs = Set(notifications.map { $0.node.id })
        notifications = incoming.filter { !existingIDs.contains($0.node.id) } + notifications
    }

    private func appendUnique(_ incoming: [NotificationEdge]) {
        let existingIDs = Set(notifications.map { $0.node.id })
        notifications.append(contentsOf: incoming.filter { !existingIDs.contains($0.node.id) })
    }

    private func mergeNewerPage(
        _ incoming: [NotificationEdge],
        nextCursor: String?,
        hasNextPage: Bool,
        usesBackwardPagination: Bool
    ) {
        guard !incoming.isEmpty else {
            hasPreviousPage = false
            pendingNewerCursor = nil
            pendingNewerInsertionIndex = nil
            pendingNewerUsesBackwardPagination = false
            return
        }

        if let insertionIndex = pendingNewerInsertionIndex {
            let existingIDs = Set(notifications.map { $0.node.id })
            let newEdges = incoming.filter { !existingIDs.contains($0.node.id) }
            notifications.insert(contentsOf: newEdges, at: min(insertionIndex, notifications.count))

            if newEdges.count < incoming.count || !hasNextPage || nextCursor == nil {
                hasPreviousPage = false
                pendingNewerCursor = nil
                pendingNewerInsertionIndex = nil
                pendingNewerUsesBackwardPagination = false
            } else {
                pendingNewerInsertionIndex = insertionIndex + newEdges.count
                pendingNewerCursor = nextCursor
                pendingNewerUsesBackwardPagination = usesBackwardPagination
                hasPreviousPage = true
            }
            return
        }

        let existingIDs = Set(notifications.map { $0.node.id })
        if let overlapIndex = incoming.firstIndex(where: { existingIDs.contains($0.node.id) }) {
            notifications = Array(incoming[..<overlapIndex]) + notifications
            hasPreviousPage = false
            pendingNewerCursor = nil
            pendingNewerInsertionIndex = nil
            pendingNewerUsesBackwardPagination = false
        } else {
            notifications = incoming + notifications
            pendingNewerInsertionIndex = incoming.count
            pendingNewerCursor = hasNextPage ? nextCursor : nil
            pendingNewerUsesBackwardPagination = usesBackwardPagination
            hasPreviousPage = hasNextPage && nextCursor != nil
        }
    }
}

struct NotificationRowView: View {
    let notification: NotificationItem
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    private var postId: String? {
        if let mention = notification.asMentionNotification {
            return mention.post?.id
        } else if let reply = notification.asReplyNotification {
            return reply.post?.id
        } else if let quote = notification.asQuoteNotification {
            return quote.post?.id
        } else if let react = notification.asReactNotification {
            return react.post?.id
        } else if let share = notification.asShareNotification {
            return share.post?.id
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                // Show first actor's avatar
                if let firstActor = notification.actors.edges.first?.node {
                    Button {
                        navigationCoordinator.navigateToProfile(handle: firstActor.handle)
                    } label: {
                        KFImage(URL(string: firstActor.avatarUrl))
                            .placeholder {
                                Color.gray.opacity(0.2)
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    notificationContent

                    Text(DateFormatHelper.relativeTime(from: notification.created))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(
            Group {
                if let postId = postId {
                    NavigationLink(destination: PostDetailView(postId: postId)) {
                        EmptyView()
                    }
                    .opacity(0)
                }
            }
        )
    }

    @ViewBuilder
    private var notificationContent: some View {
        let actors = notification.actors.edges.map { $0.node }
        let actorNamesHTML = actors.map { actor in
            if let name = actor.name {
                return name
            }
            return actor.handle
        }

        // Handle the notification type - check actual notification type via type casting
        if let _ = notification.asFollowNotification {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(.blue)
                        .frame(width: 20, height: 20)
                    notificationText(actorNamesHTML, suffix: NSLocalizedString("notifications.followedYou", comment: "Followed you notification"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else if let mentionNotification = notification.asMentionNotification {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "at")
                        .foregroundStyle(.purple)
                        .frame(width: 20, height: 20)
                    notificationText(actorNamesHTML, suffix: NSLocalizedString("notifications.mentionedYou", comment: "Mentioned you notification"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let post = mentionNotification.post {
                    postPreview(post)
                } else {
                    Text(NSLocalizedString("notifications.postUnavailable", comment: "Post unavailable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.leading, 32)
                }
            }
        } else if let replyNotification = notification.asReplyNotification {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .foregroundStyle(.green)
                        .frame(width: 20, height: 20)
                    notificationText(actorNamesHTML, suffix: NSLocalizedString("notifications.repliedToPost", comment: "Replied to post notification"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let post = replyNotification.post {
                    postPreview(post)
                } else {
                    Text(NSLocalizedString("notifications.postUnavailable", comment: "Post unavailable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.leading, 32)
                }
            }
        } else if let quoteNotification = notification.asQuoteNotification {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "quote.bubble")
                        .foregroundStyle(.orange)
                        .frame(width: 20, height: 20)
                    notificationText(actorNamesHTML, suffix: NSLocalizedString("notifications.quotedPost", comment: "Quoted post notification"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let post = quoteNotification.post {
                    postPreview(post)
                } else {
                    Text(NSLocalizedString("notifications.postUnavailable", comment: "Post unavailable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.leading, 32)
                }
            }
        } else if let reactNotification = notification.asReactNotification {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 12) {
                    Group {
                        if let emoji = reactNotification.emoji {
                            Text(emoji)
                                .font(.body)
                        } else if let customEmoji = reactNotification.customEmoji {
                            KFImage(URL(string: customEmoji.imageUrl))
                                .placeholder {
                                    Text(customEmoji.name)
                                        .font(.caption)
                                }
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "heart")
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(width: 20, height: 20)

                    notificationText(actorNamesHTML, suffix: NSLocalizedString("notifications.reactedToPost", comment: "Reacted to post notification"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let post = reactNotification.post {
                    postPreview(post)
                } else {
                    Text(NSLocalizedString("notifications.postUnavailable", comment: "Post unavailable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.leading, 32)
                }
            }
        } else if let shareNotification = notification.asShareNotification {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.2.squarepath")
                        .foregroundStyle(.blue)
                        .frame(width: 20, height: 20)
                    notificationText(actorNamesHTML, suffix: NSLocalizedString("notifications.sharedPost", comment: "Shared post notification"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let post = shareNotification.post {
                    postPreview(post)
                } else {
                    Text(NSLocalizedString("notifications.postUnavailable", comment: "Post unavailable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.leading, 32)
                }
            }
        } else {
            Text(NSLocalizedString("notifications.unknownType", comment: "Unknown notification type"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func notificationText(_ actorNamesHTML: [String], suffix: String) -> some View {
        let htmlText: String
        if actorNamesHTML.count == 1 {
            htmlText = actorNamesHTML[0] + suffix
        } else if actorNamesHTML.count == 2 {
            htmlText = actorNamesHTML[0] + NSLocalizedString("notifications.and", comment: "and") + actorNamesHTML[1] + suffix
        } else if actorNamesHTML.count > 2 {
            htmlText = actorNamesHTML[0] + String(format: NSLocalizedString("notifications.andOthers", comment: "and N others"), actorNamesHTML.count - 1) + suffix
        } else {
            htmlText = suffix
        }

        return HTMLTextView(html: htmlText, font: .subheadline)
    }

    @ViewBuilder
    private func postPreview<P: PostProtocol>(_ post: P) -> some View {
        let previewText = plainTextPreview(from: post.content)
        VStack(alignment: .leading) {
            Text(previewText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.leading, 32)
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
}
