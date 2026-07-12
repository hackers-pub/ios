import Foundation

enum BookmarkFilterRequestKind: Hashable {
    case initial
    case older
    case newer
    case refresh
}

struct BookmarkFilterRequestToken: Equatable {
    let filterID: String
    let epoch: Int
    let kind: BookmarkFilterRequestKind

    fileprivate let requestID: Int
}

/// Gives every bookmarks response ownership of both the selected filter and a
/// monotonically increasing epoch. A filter ABA transition (A -> B -> A)
/// therefore cannot let the original A response write into the current A feed.
struct BookmarkFilterRequestCoordinator {
    private(set) var selectedFilterID: String
    private(set) var epoch = 0

    private var nextRequestID = 0
    private var activeRequestID: Int?

    init(filterID: String) {
        selectedFilterID = filterID
    }

    mutating func select(filterID: String) {
        invalidateActiveRequests()
        selectedFilterID = filterID
    }

    mutating func invalidateActiveRequests() {
        epoch &+= 1
        activeRequestID = nil
    }

    mutating func begin(_ kind: BookmarkFilterRequestKind) -> BookmarkFilterRequestToken {
        nextRequestID &+= 1
        activeRequestID = nextRequestID
        return BookmarkFilterRequestToken(
            filterID: selectedFilterID,
            epoch: epoch,
            kind: kind,
            requestID: nextRequestID
        )
    }

    func isCurrent(_ token: BookmarkFilterRequestToken) -> Bool {
        token.filterID == selectedFilterID
            && token.epoch == epoch
            && activeRequestID == token.requestID
    }

    @discardableResult
    mutating func finish(_ token: BookmarkFilterRequestToken) -> Bool {
        guard isCurrent(token) else { return false }
        activeRequestID = nil
        return true
    }
}
