import Foundation

struct NotificationListRequest {
    let session: NotificationReadSession
    let unreadRequest: NotificationUnreadRequest
}

enum NotificationsLoadError: LocalizedError {
    case missingViewer
    case graphQLError(String)

    var errorDescription: String? {
        switch self {
        case let .graphQLError(message) where !message.isEmpty:
            message
        case .missingViewer, .graphQLError:
            NSLocalizedString("notifications.load.error", comment: "Unable to load notifications")
        }
    }
}
