import SwiftUI
import Kingfisher
@preconcurrency import Apollo

typealias NotificationItem = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node

protocol NotificationActorProtocol {
    var id: String { get }
    var name: String? { get }
    var handle: String { get }
    var avatarUrl: String { get }
}

extension HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.Actors.Edge.Node: NotificationActorProtocol {}

struct NotificationsView: View {
    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var shouldRefresh = false
    @State private var showingSettings = false
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        NavigationStack(path: Bindable(navigationCoordinator).path) {
            Group {
                if isLoading && notifications.isEmpty {
                    ProgressView()
                } else if notifications.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("notifications.empty.title", comment: "No notifications title"),
                        systemImage: "bell.slash",
                        description: Text(NSLocalizedString("notifications.empty.description", comment: "No notifications description"))
                    )
                } else {
                    List {
                        ForEach(notifications, id: \.id) { notification in
                            NotificationRowView(notification: notification)
                                .onAppear {
                                    if notification.id == notifications.last?.id && hasNextPage && !isLoading {
                                        Task {
                                            await loadMore()
                                        }
                                    }
                                }
                        }

                        if isLoading && !notifications.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
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
                await fetchNotifications()
            }
            .onChange(of: shouldRefresh) { _, newValue in
                if newValue {
                    Task {
                        await refreshNotifications()
                        shouldRefresh = false
                    }
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
                }
            }
        }
    }

    private func fetchNotifications() async {
        print("🔔 NotificationsView: Starting to fetch notifications...")
        isLoading = true
        defer { isLoading = false }

        do {
            print("🔔 NotificationsView: Calling apolloClient.fetch...")
            let response = try await apolloClient.fetch(query: HackersPub.NotificationsQuery(after: nil))
            print("🔔 NotificationsView: Got response, data exists: \(response.data != nil)")

            if let errors = response.errors, !errors.isEmpty {
                print("⚠️ NotificationsView: GraphQL errors present:")
                for error in errors {
                    print("   - \(error.message ?? "Unknown error")")
                }
            }

            let fetchedNotifications = response.data?.viewer?.notifications.edges.map { $0.node } ?? []
            print("🔔 NotificationsView: Fetched notifications count: \(fetchedNotifications.count)")

            notifications = fetchedNotifications
            hasNextPage = response.data?.viewer?.notifications.pageInfo.hasNextPage ?? false
            endCursor = response.data?.viewer?.notifications.pageInfo.endCursor
        } catch {
            print("❌ NotificationsView: Error fetching notifications: \(error)")
        }
    }

    private func loadMore() async {
        guard let cursor = endCursor, hasNextPage else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.NotificationsQuery(after: .some(cursor)))
            let newNotifications = response.data?.viewer?.notifications.edges.map { $0.node } ?? []
            notifications.append(contentsOf: newNotifications)
            hasNextPage = response.data?.viewer?.notifications.pageInfo.hasNextPage ?? false
            endCursor = response.data?.viewer?.notifications.pageInfo.endCursor
        } catch {
            print("❌ NotificationsView: Error loading more notifications: \(error)")
        }
    }

    private func refreshNotifications() async {
        print("🔔 NotificationsView: Refreshing notifications...")
        isLoading = true
        defer { isLoading = false }

        do {
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.NotificationsQuery(after: nil))
            let fetchedNotifications = response.data?.viewer?.notifications.edges.map { $0.node } ?? []
            notifications = fetchedNotifications
            hasNextPage = response.data?.viewer?.notifications.pageInfo.hasNextPage ?? false
            endCursor = response.data?.viewer?.notifications.pageInfo.endCursor
        } catch {
            print("❌ NotificationsView: Error refreshing notifications: \(error)")
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
        VStack(alignment: .leading) {
            HTMLTextView(html: post.content, font: .caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.leading, 32)
    }
}
