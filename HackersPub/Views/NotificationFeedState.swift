import Foundation

/// A page from the server-ordered notification connection. The connection is
/// newest first, so `endCursor` is the only cursor used to continue toward
/// older notifications.
struct NotificationFeedPage<Item> {
    let items: [Item]
    let startCursor: String?
    let endCursor: String?
    let hasNextPage: Bool
}

enum NotificationFeedRequestKind: Equatable {
    case latest
    case gap
    case older
}

/// Notifications only advance toward older rows with an `after` cursor.
/// Keeping this as a single-case enum makes an unreachable backward branch
/// impossible to represent in the feed coordinator.
enum NotificationFeedCursorDirection: Equatable {
    case after
}

struct NotificationFeedRequest: Equatable {
    let kind: NotificationFeedRequestKind
    let cursor: String?
    let direction: NotificationFeedCursorDirection

    fileprivate let epoch: Int
    fileprivate let requestID: Int
    fileprivate let gapEpoch: Int
}

enum NotificationFeedResult<Item> {
    case success(NotificationFeedPage<Item>)
    case failure(String)
    case cancelled
}

/// Owns the independent request slots for the notifications feed.
///
/// A latest request always starts from the first page. Gap completion follows
/// that page's `endCursor` and never blocks a later latest request. Server
/// pages are merged by notification identity instead of overlap position so
/// aggregated notifications can move without dropping rows below them.
struct NotificationFeedState<Item> {
    private let itemID: (Item) -> String

    private(set) var items: [Item] = []
    private(set) var startCursor: String?
    private(set) var endCursor: String?
    private(set) var hasNextPage = false
    private(set) var pendingGapCursor: String?
    private(set) var pendingGapInsertionIndex: Int?
    private(set) var errorMessage: String?
    private(set) var isLatestLoading = false
    private(set) var isGapLoading = false
    private(set) var isOlderLoading = false

    private var epoch = 0
    private var latestRequestID = 0
    private var gapRequestID = 0
    private var olderRequestID = 0
    private var gapEpoch = 0
    private var hasQueuedLatestRequest = false

    init(id: @escaping (Item) -> String) {
        itemID = id
    }

    var isLoading: Bool {
        isLatestLoading || isGapLoading || isOlderLoading
    }

    var hasPendingGap: Bool {
        pendingGapCursor != nil && pendingGapInsertionIndex != nil
    }

    mutating func reset() {
        epoch &+= 1
        gapEpoch &+= 1
        latestRequestID = 0
        gapRequestID = 0
        olderRequestID = 0
        hasQueuedLatestRequest = false
        isLatestLoading = false
        isGapLoading = false
        isOlderLoading = false
        items = []
        startCursor = nil
        endCursor = nil
        hasNextPage = false
        clearGap()
        errorMessage = nil
    }

    mutating func replaceInitial(with page: NotificationFeedPage<Item>) {
        reset()
        items = deduplicated(page.items)
        startCursor = page.startCursor
        endCursor = page.endCursor
        hasNextPage = page.hasNextPage
    }
}

extension NotificationFeedState {
    /// Starts a first-page request. A second caller does not start another
    /// network operation; it records one trailing request for the current
    /// caller to perform after completion.
    mutating func beginLatestRequest() -> NotificationFeedRequest? {
        if isLatestLoading {
            hasQueuedLatestRequest = true
            return nil
        }

        return startLatestRequest()
    }

    /// Completes a latest request and returns a single queued follow-up, if a
    /// caller asked for one while this request was running.
    mutating func finishLatest(
        _ request: NotificationFeedRequest,
        with result: NotificationFeedResult<Item>
    ) -> NotificationFeedRequest? {
        guard isCurrentLatest(request) else { return nil }

        isLatestLoading = false

        switch result {
        case let .success(page):
            applyLatestPage(page)
            errorMessage = nil
        case let .failure(message):
            errorMessage = message
        case .cancelled:
            // Cancellation is an expected lifecycle event. Keep visible rows
            // and make the request immediately retryable.
            errorMessage = nil
        }

        guard hasQueuedLatestRequest else { return nil }
        hasQueuedLatestRequest = false
        return startLatestRequest()
    }

    mutating func beginGapRequest() -> NotificationFeedRequest? {
        guard !isGapLoading,
              let cursor = pendingGapCursor,
              pendingGapInsertionIndex != nil
        else {
            return nil
        }

        gapRequestID &+= 1
        isGapLoading = true
        return NotificationFeedRequest(
            kind: .gap,
            cursor: cursor,
            direction: .after,
            epoch: epoch,
            requestID: gapRequestID,
            gapEpoch: gapEpoch
        )
    }

    /// Returns false when a later latest result has invalidated this gap
    /// request. A stale result must not rewrite the freshly merged feed.
    @discardableResult
    mutating func finishGap(
        _ request: NotificationFeedRequest,
        with result: NotificationFeedResult<Item>
    ) -> Bool {
        guard isCurrentGap(request) else { return false }

        isGapLoading = false

        switch result {
        case let .success(page):
            applyGapPage(page, requestedCursor: request.cursor)
            errorMessage = nil
        case let .failure(message):
            errorMessage = message
        case .cancelled:
            errorMessage = nil
        }

        return true
    }

    /// The bottom-of-list trigger is the reachable older-page path. It uses
    /// the aggregate list's current end cursor and has no backward variant.
    mutating func beginOlderRequest() -> NotificationFeedRequest? {
        guard !isOlderLoading, hasNextPage, let cursor = endCursor else {
            return nil
        }

        olderRequestID &+= 1
        isOlderLoading = true
        return NotificationFeedRequest(
            kind: .older,
            cursor: cursor,
            direction: .after,
            epoch: epoch,
            requestID: olderRequestID,
            gapEpoch: gapEpoch
        )
    }

    @discardableResult
    mutating func finishOlder(
        _ request: NotificationFeedRequest,
        with result: NotificationFeedResult<Item>
    ) -> Bool {
        guard isCurrentOlder(request) else { return false }

        isOlderLoading = false

        switch result {
        case let .success(page):
            appendPage(page)
            errorMessage = nil
        case let .failure(message):
            errorMessage = message
        case .cancelled:
            errorMessage = nil
        }

        return true
    }
}

private extension NotificationFeedState {
    private mutating func startLatestRequest() -> NotificationFeedRequest {
        invalidateOlder()
        latestRequestID &+= 1
        isLatestLoading = true
        errorMessage = nil
        return NotificationFeedRequest(
            kind: .latest,
            cursor: nil,
            direction: .after,
            epoch: epoch,
            requestID: latestRequestID,
            gapEpoch: gapEpoch
        )
    }

    private func isCurrentLatest(_ request: NotificationFeedRequest) -> Bool {
        request.kind == .latest
            && request.epoch == epoch
            && request.requestID == latestRequestID
            && isLatestLoading
    }

    private func isCurrentGap(_ request: NotificationFeedRequest) -> Bool {
        request.kind == .gap
            && request.epoch == epoch
            && request.requestID == gapRequestID
            && request.gapEpoch == gapEpoch
            && isGapLoading
    }

    private func isCurrentOlder(_ request: NotificationFeedRequest) -> Bool {
        request.kind == .older
            && request.epoch == epoch
            && request.requestID == olderRequestID
            && isOlderLoading
    }

    private mutating func applyLatestPage(_ page: NotificationFeedPage<Item>) {
        // Invalidate older work before an authoritative first-page commit so
        // late completion cannot rewrite rows, cursors, errors, or loading.
        invalidateOlder()
        let incoming = deduplicated(page.items)
        let previousItems = items
        let previousIDs = Set(previousItems.map(itemID))
        let incomingIDs = Set(incoming.map(itemID))

        // A full first page with no following page is authoritative. Retaining
        // local tail rows in this case would preserve server-deleted rows.
        if !page.hasNextPage {
            items = incoming
            startCursor = page.startCursor
            endCursor = page.endCursor
            hasNextPage = false
            invalidateGap()
            return
        }

        if previousItems.isEmpty {
            items = incoming
            endCursor = page.endCursor
            hasNextPage = page.hasNextPage
        } else {
            // Incoming order is server order. Removing all incoming identities
            // first replaces stale aggregate payloads and moves them to the
            // correct order before retaining older known rows.
            items = incoming + previousItems.filter { !incomingIDs.contains(itemID($0)) }
            hasNextPage = hasNextPage || page.hasNextPage
        }
        startCursor = page.startCursor

        // A first-page overlap is not enough to prove continuity: an aggregate
        // may have moved to the top while unseen rows still follow the page.
        // Only an existing final item closes the gap.
        let connectsToKnownRows = incoming.last.map { previousIDs.contains(itemID($0)) } ?? true
        invalidateGap()
        let shouldOpenGap = !previousItems.isEmpty && !connectsToKnownRows && !incoming.isEmpty
        if shouldOpenGap, let cursor = page.endCursor {
            pendingGapCursor = cursor
            pendingGapInsertionIndex = incoming.count
        }
    }

    private mutating func applyGapPage(
        _ page: NotificationFeedPage<Item>,
        requestedCursor: String?
    ) {
        guard let insertionIndex = pendingGapInsertionIndex else {
            return
        }

        let incoming = deduplicated(page.items)
        guard !incoming.isEmpty else {
            clearGap()
            return
        }

        let incomingIDs = Set(incoming.map(itemID))
        let existingItems = items
        let existingIDs = Set(existingItems.map(itemID))
        let boundedIndex = min(insertionIndex, existingItems.count)
        let removedBeforeInsertion = existingItems.prefix(boundedIndex).reduce(into: 0) { count, item in
            if incomingIDs.contains(itemID(item)) {
                count += 1
            }
        }
        let adjustedInsertionIndex = max(0, boundedIndex - removedBeforeInsertion)

        var merged = existingItems.filter { !incomingIDs.contains(itemID($0)) }
        merged.insert(contentsOf: incoming, at: min(adjustedInsertionIndex, merged.count))
        items = merged

        let connectsToKnownRows = incoming.last.map { existingIDs.contains(itemID($0)) } ?? true
        let nextCursor = page.endCursor
        let shouldContinueGap = page.hasNextPage && !connectsToKnownRows && nextCursor != requestedCursor
        if shouldContinueGap, let nextCursor {
            pendingGapCursor = nextCursor
            pendingGapInsertionIndex = adjustedInsertionIndex + incoming.count
        } else {
            clearGap()
        }
    }

    private mutating func appendPage(_ page: NotificationFeedPage<Item>) {
        let incoming = deduplicated(page.items)
        var replacements = Dictionary(uniqueKeysWithValues: incoming.map { (itemID($0), $0) })
        var appendedIDs = Set(items.map(itemID))

        for index in items.indices {
            let id = itemID(items[index])
            if let replacement = replacements.removeValue(forKey: id) {
                items[index] = replacement
            }
        }

        for item in incoming {
            let id = itemID(item)
            if appendedIDs.insert(id).inserted {
                items.append(item)
            }
        }

        hasNextPage = page.hasNextPage
        endCursor = page.endCursor
    }

    private func deduplicated(_ candidates: [Item]) -> [Item] {
        var seen = Set<String>()
        return candidates.filter { seen.insert(itemID($0)).inserted }
    }

    private mutating func invalidateGap() {
        gapEpoch &+= 1
        isGapLoading = false
        clearGap()
    }

    private mutating func invalidateOlder() {
        olderRequestID &+= 1
        isOlderLoading = false
    }

    private mutating func clearGap() {
        pendingGapCursor = nil
        pendingGapInsertionIndex = nil
    }
}
