import Foundation
import Kingfisher
import SwiftUI

typealias NotificationItem = HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node

func notificationActorAccessibilityLabel(name: String?, handle: String) -> String {
    name.flatMap(previewPlainText) ?? handle
}

struct NotificationRowView: View {
    let notification: NotificationItem
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
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
                    .accessibilityLabel(
                        notificationActorAccessibilityLabel(name: firstActor.name, handle: firstActor.handle)
                    )
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
    }

    @ViewBuilder
    private var notificationContent: some View {
        let actors = notification.actors.edges.map(\.node)
        let actorNamesHTML = actors.map { actor in
            actor.name ?? actor.handle
        }

        if notification.asFollowNotification != nil {
            notificationSummary(
                icon: "person.badge.plus",
                color: .blue,
                actorNamesHTML: actorNamesHTML,
                kind: .followed
            )
        } else if let mentionNotification = notification.asMentionNotification {
            notificationWithPost(
                icon: "at",
                color: .purple,
                actorNamesHTML: actorNamesHTML,
                kind: .mentioned,
                preview: mentionNotification.post.map(NotificationPostPreview.init)
            )
        } else if let replyNotification = notification.asReplyNotification {
            notificationWithPost(
                icon: "arrowshape.turn.up.left",
                color: .green,
                actorNamesHTML: actorNamesHTML,
                kind: .replied,
                preview: replyNotification.post.map(NotificationPostPreview.init)
            )
        } else if let quoteNotification = notification.asQuoteNotification {
            notificationWithPost(
                icon: "quote.bubble",
                color: .orange,
                actorNamesHTML: actorNamesHTML,
                kind: .quoted,
                preview: quoteNotification.post.map(NotificationPostPreview.init)
            )
        } else if let reactNotification = notification.asReactNotification {
            reactionNotification(actorNamesHTML: actorNamesHTML, notification: reactNotification)
        } else if let shareNotification = notification.asShareNotification {
            notificationWithPost(
                icon: "arrow.2.squarepath",
                color: .blue,
                actorNamesHTML: actorNamesHTML,
                kind: .shared,
                preview: shareNotification.post.map(NotificationPostPreview.init)
            )
        } else {
            Text(NSLocalizedString("notifications.unknownType", comment: "Unknown notification type"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func notificationSummary(
        icon: String,
        color: Color,
        actorNamesHTML: [String],
        kind: NotificationMessageKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20, height: 20)
                notificationText(actorNamesHTML, kind: kind)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func notificationWithPost(
        icon: String,
        color: Color,
        actorNamesHTML: [String],
        kind: NotificationMessageKind,
        preview: NotificationPostPreview?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20, height: 20)
                notificationText(actorNamesHTML, kind: kind)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let preview {
                notificationPreview(preview)
            } else {
                unavailablePostText
            }
        }
    }

    private func reactionNotification(
        actorNamesHTML: [String],
        notification: HackersPub.NotificationsQuery.Data.Viewer.Notifications.Edge.Node.AsReactNotification
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let emoji = notification.emoji {
                        Text(emoji)
                            .font(.body)
                    } else if let customEmoji = notification.customEmoji {
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

                notificationText(actorNamesHTML, kind: .reacted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let preview = notification.post.map(NotificationPostPreview.init) {
                notificationPreview(preview)
            } else {
                unavailablePostText
            }
        }
    }

    private func notificationPreview(_ preview: NotificationPostPreview) -> some View {
        NotificationPostPreviewView(preview: preview) { action in
            switch action {
            case let .openDetail(postID):
                navigationCoordinator.navigateToPost(id: postID)
            }
        }
    }

    private var unavailablePostText: some View {
        Text(NSLocalizedString("notifications.postUnavailable", comment: "Post unavailable"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .italic()
            .padding(.leading, 32)
    }

    private func notificationText(_ actorNamesHTML: [String], kind: NotificationMessageKind) -> some View {
        let message = NotificationMessageFormatter.format(actorNames: actorNamesHTML, kind: kind)
        return HTMLTextView(html: message.html, font: .subheadline)
            .accessibilityLabel(message.accessibilityText)
    }
}

private struct NotificationPostPreviewView: View {
    let presentation: NotificationPostPreviewPresentation
    let onAction: (NotificationPostPreviewAction) -> Void

    init(preview: any PostPreviewProtocol, onAction: @escaping (NotificationPostPreviewAction) -> Void) {
        presentation = NotificationPostPreviewPresentation(preview: preview)
        self.onAction = onAction
    }

    var body: some View {
        if let action = presentation.action {
            Button {
                onAction(action)
            } label: {
                cardContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(NSLocalizedString("notifications.post.open", comment: "Open post"))
        } else {
            cardContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if presentation.authorName != nil || presentation.published != nil {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let authorName = presentation.authorName {
                        if let avatarURL = presentation.authorAvatarURL {
                            KFImage(avatarURL)
                                .placeholder { Color.gray.opacity(0.2) }
                                .resizable()
                                .scaledToFill()
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                                .accessibilityHidden(true)
                        }
                        Text(authorName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    if let authorHandle = presentation.authorHandle {
                        Text(authorHandle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let published = presentation.published {
                        Text(DateFormatHelper.relativeTime(from: published))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if let title = presentation.title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let body = presentation.body {
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(NSLocalizedString("notifications.post.previewUnavailable", comment: "Unavailable post preview"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let thumbnailURL = presentation.thumbnailURL {
                KFImage(thumbnailURL)
                    .placeholder { Color.gray.opacity(0.15) }
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(10)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private var accessibilityLabel: String {
        let fallback = NSLocalizedString("notifications.post.previewUnavailable", comment: "Unavailable post preview")
        return presentation.accessibilityLabel.isEmpty ? fallback : presentation.accessibilityLabel
    }
}
