@preconcurrency import Apollo
import ApolloAPI
import Foundation

struct NotificationReadSession: Hashable {
    let accountID: String
    let sessionToken: String
}

@MainActor
func currentNotificationReadSession(for authManager: AuthManager) -> NotificationReadSession? {
    guard authManager.isAuthenticated,
          let accountID = authManager.currentAccount?.id,
          let sessionToken = authManager.sessionToken
    else {
        return nil
    }

    return NotificationReadSession(accountID: accountID, sessionToken: sessionToken)
}

struct NotificationUnreadRequest: Equatable {
    fileprivate let session: NotificationReadSession
    fileprivate let epoch: Int
    fileprivate let generation: Int
}

enum NotificationReadMarkOutcome: Equatable {
    case marked
    case failed(String)
    case ignored
}

struct NotificationReadPresentation: Equatable {
    let badgeCount: Int
    let readErrorMessage: String?
    let isMarking: Bool

    var showsReadRetry: Bool {
        readErrorMessage != nil
    }
}

typealias NotificationReadMarker = @MainActor (String) async throws -> Void
typealias NotificationUnreadCountFetcher = @MainActor (NotificationReadSession) async throws -> Int

private struct NotificationReadBoundary: Hashable {
    let session: NotificationReadSession
    let notificationUUID: String
}

enum NotificationReadError: LocalizedError {
    case missingViewer
    case unexpectedViewer
    case missingMarkResult
    case graphQLError(String)

    var errorDescription: String? {
        switch self {
        case let .graphQLError(message) where !message.isEmpty:
            return message
        case .missingViewer, .unexpectedViewer, .missingMarkResult, .graphQLError:
            return NSLocalizedString("notifications.read.error", comment: "Unable to sync notification read status")
        }
    }
}

@Observable
@MainActor
final class NotificationReadState {
    private static let completedBoundaryLimit = 128

    private(set) var unreadCount: Int?
    private(set) var markReadErrorMessage: String?
    private let markOperation: NotificationReadMarker
    private let fetchUnreadCountOperation: NotificationUnreadCountFetcher
    private var activeSession: NotificationReadSession?
    private var unreadEpoch = 0
    private var newestRequestGeneration = 0
    private var processingID: UUID?
    private var pendingBoundary: NotificationReadBoundary?
    private var inFlightBoundary: NotificationReadBoundary?
    private var completedBoundaries: Set<NotificationReadBoundary> = []
    private var completedBoundaryOrder: [NotificationReadBoundary] = []

    init(
        mark: NotificationReadMarker? = nil,
        fetchUnreadCount: NotificationUnreadCountFetcher? = nil
    ) {
        markOperation = mark ?? { notificationUUID in
            try await markNotificationsAsRead(upTo: notificationUUID)
        }
        fetchUnreadCountOperation = fetchUnreadCount ?? { session in
            try await fetchNotificationUnreadCount(for: session)
        }
    }

    var badgeCount: Int {
        max(0, unreadCount ?? 0)
    }

    var isMarkingNotificationsRead: Bool {
        processingID != nil
    }

    var presentation: NotificationReadPresentation {
        NotificationReadPresentation(
            badgeCount: badgeCount,
            readErrorMessage: markReadErrorMessage,
            isMarking: isMarkingNotificationsRead
        )
    }

    func beginUnreadRequest(for session: NotificationReadSession?) -> NotificationUnreadRequest? {
        activate(session)
        guard let session, !Task.isCancelled else { return nil }

        newestRequestGeneration += 1
        return NotificationUnreadRequest(
            session: session,
            epoch: unreadEpoch,
            generation: newestRequestGeneration
        )
    }

    @discardableResult
    func applyUnreadCount(_ count: Int, for request: NotificationUnreadRequest) -> Bool {
        guard isCurrent(request) else { return false }
        unreadCount = max(0, count)
        return true
    }

    func refreshUnreadCount(for session: NotificationReadSession?) async {
        guard let request = beginUnreadRequest(for: session) else { return }

        do {
            let count = try await fetchUnreadCountOperation(request.session)
            _ = applyUnreadCount(count, for: request)
        } catch {
            // Keep the last server-confirmed badge value until a later refresh succeeds.
        }
    }

    func markDisplayedNotificationsAsRead(
        upTo notificationUUID: String,
        for session: NotificationReadSession?
    ) async -> NotificationReadMarkOutcome {
        activate(session)
        guard let session, !Task.isCancelled else { return .ignored }

        let boundary = NotificationReadBoundary(
            session: session,
            notificationUUID: notificationUUID
        )
        // swiftlint:disable opening_brace
        if !completedBoundaries.contains(boundary),
           inFlightBoundary != boundary,
           pendingBoundary != boundary
        {
            // Notification connections are newest-first. While an older boundary
            // is in flight, the latest visible boundary supersedes older pending work.
            pendingBoundary = boundary
        }
        // swiftlint:enable opening_brace

        guard processingID == nil, pendingBoundary == boundary else { return .ignored }

        let processingID = UUID()
        self.processingID = processingID
        return await processPendingBoundaries(processingID: processingID)
    }

    private func activate(_ session: NotificationReadSession?) {
        guard activeSession != session else { return }

        activeSession = session
        unreadCount = nil
        markReadErrorMessage = nil
        unreadEpoch += 1
        newestRequestGeneration = 0
        processingID = nil
        pendingBoundary = nil
        inFlightBoundary = nil
        completedBoundaries.removeAll()
        completedBoundaryOrder.removeAll()
    }

    private func isCurrent(_ request: NotificationUnreadRequest) -> Bool {
        !Task.isCancelled
            && activeSession == request.session
            && unreadEpoch == request.epoch
            && newestRequestGeneration == request.generation
            && processingID == nil
    }

    // Splitting this transition risks changing cancellation and session-ownership ordering.
    // swiftlint:disable:next function_body_length
    private func processPendingBoundaries(processingID: UUID) async -> NotificationReadMarkOutcome {
        var latestOutcome: NotificationReadMarkOutcome = .ignored

        // swiftlint:disable opening_brace
        while self.processingID == processingID,
              let boundary = pendingBoundary,
              boundary.session == activeSession
        {
            pendingBoundary = nil
            inFlightBoundary = boundary
            unreadEpoch += 1

            do {
                try await markOperation(boundary.notificationUUID)
                guard isCurrentProcessing(
                    processingID: processingID,
                    boundary: boundary
                ) else {
                    abandonProcessingIfOwned(processingID: processingID, boundary: boundary)
                    return .ignored
                }

                unreadEpoch += 1
                let count = try await fetchUnreadCountOperation(boundary.session)
                guard isCurrentProcessing(
                    processingID: processingID,
                    boundary: boundary
                ) else {
                    abandonProcessingIfOwned(processingID: processingID, boundary: boundary)
                    return .ignored
                }

                unreadCount = max(0, count)
                markReadErrorMessage = nil
                recordCompleted(boundary)
                inFlightBoundary = nil
                unreadEpoch += 1
                latestOutcome = .marked
            } catch is CancellationError {
                abandonProcessingIfOwned(processingID: processingID, boundary: boundary)
                return .ignored
            } catch {
                guard !Task.isCancelled else {
                    abandonProcessingIfOwned(processingID: processingID, boundary: boundary)
                    return .ignored
                }
                guard isCurrentProcessing(
                    processingID: processingID,
                    boundary: boundary,
                    requiresActiveTask: false
                ) else {
                    abandonProcessingIfOwned(processingID: processingID, boundary: boundary)
                    return .ignored
                }

                let message = error.localizedDescription.isEmpty
                    ? NSLocalizedString("notifications.read.error", comment: "Unable to sync notification read status")
                    : error.localizedDescription
                markReadErrorMessage = message
                inFlightBoundary = nil
                self.processingID = nil
                unreadEpoch += 1
                return .failed(message)
            }
        }
        // swiftlint:enable opening_brace

        if self.processingID == processingID {
            self.processingID = nil
            inFlightBoundary = nil
        }
        return latestOutcome
    }

    private func isCurrentProcessing(
        processingID: UUID,
        boundary: NotificationReadBoundary,
        requiresActiveTask: Bool = true
    ) -> Bool {
        (!requiresActiveTask || !Task.isCancelled)
            && self.processingID == processingID
            && activeSession == boundary.session
            && inFlightBoundary == boundary
    }

    private func abandonProcessingIfOwned(
        processingID: UUID,
        boundary: NotificationReadBoundary
    ) {
        guard self.processingID == processingID else { return }
        if inFlightBoundary == boundary {
            inFlightBoundary = nil
        }
        self.processingID = nil
        unreadEpoch += 1
    }

    private func recordCompleted(_ boundary: NotificationReadBoundary) {
        guard completedBoundaries.insert(boundary).inserted else { return }
        completedBoundaryOrder.append(boundary)

        if completedBoundaryOrder.count > Self.completedBoundaryLimit {
            let expiredBoundary = completedBoundaryOrder.removeFirst()
            completedBoundaries.remove(expiredBoundary)
        }
    }
}

func fetchNotificationUnreadCount(for session: NotificationReadSession) async throws -> Int {
    let response = try await apolloClient.fetch(
        query: HackersPub.NotificationUnreadCountQuery(),
        cachePolicy: .networkOnly
    )

    if let error = response.errors?.first {
        throw NotificationReadError.graphQLError(error.message ?? "")
    }
    guard let viewer = response.data?.viewer else {
        throw NotificationReadError.missingViewer
    }
    guard viewer.id == session.accountID else {
        throw NotificationReadError.unexpectedViewer
    }
    return viewer.unreadNotificationsCount
}

func markNotificationsAsRead(upTo notificationUUID: String) async throws {
    let response = try await apolloClient.perform(
        mutation: HackersPub.MarkNotificationsAsReadMutation(upTo: .some(notificationUUID))
    )

    if let error = response.errors?.first {
        throw NotificationReadError.graphQLError(error.message ?? "")
    }
    guard response.data?.markNotificationsAsRead != nil else {
        throw NotificationReadError.missingMarkResult
    }
}
