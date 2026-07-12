import SwiftUI

struct NotificationFeedContent: View {
    let notifications: [NotificationEdge]
    let isLoading: Bool
    let hasNextPage: Bool
    let errorMessage: String?
    let pendingGapInsertionIndex: Int?
    let isGapLoading: Bool
    let readErrorMessage: String?
    let isMarkingRead: Bool
    let loadNewer: () async -> Void
    let loadMore: () async -> Void
    let retryLoad: () async -> Void
    let queueVisibleNotificationForRead: (String) -> Void
    let retryMarkingVisibleNotificationsAsRead: () -> Void
    @Binding var scrollViewport: FeedViewportSnapshot<String>
    @Binding var scrollRestoreRequest: FeedScrollAnchorPolicy<String>.Restoration?

    var body: some View {
        VStack(spacing: 0) {
            if let readErrorMessage {
                NotificationReadSyncFailureBanner(
                    message: readErrorMessage,
                    isRetrying: isMarkingRead,
                    onRetry: retryMarkingVisibleNotificationsAsRead
                )
                Divider()
            }

            FeedAnchorScrollView(
                viewport: $scrollViewport,
                restoration: $scrollRestoreRequest
            ) {
                LazyVStack(spacing: 0) {
                    if pendingGapInsertionIndex == 0 {
                        NotificationGapFillRow(isLoading: isGapLoading) {
                            Task {
                                await loadNewer()
                            }
                        }
                        Divider()
                    }

                    ForEach(Array(notifications.enumerated()), id: \.element.node.id) { index, notification in
                        NotificationRowView(notification: notification.node)
                            .padding()
                            .feedScrollAnchor(id: notification.node.id)
                            .id(notification.node.id)
                            .onAppear {
                                if notification.node.uuid == notifications.first?.node.uuid {
                                    queueVisibleNotificationForRead(notification.node.uuid)
                                }
                                let isLastNotification = notification.node.id == notifications.last?.node.id
                                if isLastNotification && hasNextPage && !isLoading {
                                    Task {
                                        await loadMore()
                                    }
                                }
                            }

                        Divider()

                        if pendingGapInsertionIndex == index + 1 {
                            NotificationGapFillRow(isLoading: isGapLoading) {
                                Task {
                                    await loadNewer()
                                }
                            }
                            Divider()
                        }
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
                                await retryLoad()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct NotificationGapFillRow: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView()
                } else {
                    Label(
                        NSLocalizedString("notifications.loadGap", comment: "Load missing notification gap"),
                        systemImage: "arrow.down"
                    )
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(NSLocalizedString("notifications.loadGap", comment: "Load missing notification gap"))
    }
}

struct NotificationReadSyncFailureBanner: View {
    let message: String
    let isRetrying: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("notifications.read.error", comment: "Unable to sync notification read status"))
                .font(.footnote)
                .fontWeight(.semibold)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: onRetry) {
                HStack(spacing: 6) {
                    if isRetrying {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(NSLocalizedString("notifications.read.retry", comment: "Retry marking notifications as read"))
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRetrying)
            .accessibilityLabel(
                NSLocalizedString("notifications.read.retry", comment: "Retry marking notifications as read")
            )
            .accessibilityIdentifier("notifications.read.retry")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .accessibilityElement(children: .contain)
    }
}
