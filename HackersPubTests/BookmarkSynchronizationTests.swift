import Foundation
@testable import HackersPub
import Testing

struct BookmarkSynchronizationTests {
    @Test func bookmarkPropagationNeverBroadcastsRollback() {
        var changes: [(String, Bool)] = []
        let notify: (String, Bool) -> Void = { changes.append(($0, $1)) }

        _ = PostBookmarkChangePropagation.resolve(
            postID: "post",
            authoritativeState: nil,
            fallbackState: false,
            onChange: notify
        )

        #expect(changes.isEmpty)
    }

    @Test func bookmarkSuccessPublishesTypedSemanticEventForDetailAndLists() {
        let center = NotificationCenter()
        let recorder = PostContentEventRecorder()
        let observer = center.addObserver(forName: .postContentDidChange, object: nil, queue: nil) { notification in
            if let event = PostContentEventCenter.event(from: notification) {
                recorder.append(event)
            }
        }
        defer { center.removeObserver(observer) }

        let resolved = PostBookmarkChangePropagation.resolve(
            postID: "original",
            authoritativeState: false,
            fallbackState: true,
            onChange: nil,
            center: center
        )

        #expect(!resolved)
        #expect(recorder.events == [.bookmarkChanged(postID: "original", isBookmarked: false)])
        #expect(
            PostBookmarkContentEventRouter.bookmarkedState(
                from: .bookmarkChanged(postID: "original", isBookmarked: false),
                targetPostID: "original"
            ) == false
        )
        #expect(
            PostBookmarkContentEventRouter.bookmarkedState(
                from: .bookmarkChanged(postID: "other", isBookmarked: true),
                targetPostID: "original"
            ) == nil
        )
        #expect(
            PostContentListEventRouter.route(
                .bookmarkChanged(postID: "original", isBookmarked: false),
                host: .bookmarks,
                rows: [PostListItemIdentity(rowID: "wrapper", postID: "wrapper", displayedPostID: "original")],
                eventGeneration: 1,
                activeGeneration: 1
            ) == .remove(rowIDs: ["wrapper"])
        )
    }

    @Test func bookmarkFailureDoesNotPublishTypedEvent() {
        let center = NotificationCenter()
        let recorder = PostContentEventRecorder()
        let observer = center.addObserver(forName: .postContentDidChange, object: nil, queue: nil) { _ in
            recorder.append(.postDeleted(postID: "unexpected"))
        }
        defer { center.removeObserver(observer) }

        let resolved = PostBookmarkChangePropagation.resolve(
            postID: "original",
            authoritativeState: nil,
            fallbackState: true,
            onChange: nil,
            center: center
        )

        #expect(resolved)
        #expect(recorder.events.isEmpty)
    }
}

private final class PostContentEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedEvents: [PostContentEvent] = []

    var events: [PostContentEvent] {
        lock.lock()
        defer { lock.unlock() }
        return recordedEvents
    }

    func append(_ event: PostContentEvent) {
        lock.lock()
        defer { lock.unlock() }
        recordedEvents.append(event)
    }
}
