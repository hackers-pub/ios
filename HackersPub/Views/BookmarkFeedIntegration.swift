enum BookmarkFeedPostContentAction: Equatable {
    case none
    case authoritativeRefresh
    case remove(nodeIDs: [String])
}

enum BookmarkFeedNewerPageScrollAnchorAction: Equatable {
    case none
    case restore
    case reset
}

struct BookmarkFeedNewerPageMerge {
    let edges: [BookmarkEdge]
    let pendingNewerCursor: String?
    let hasPreviousPage: Bool
    let scrollAnchorAction: BookmarkFeedNewerPageScrollAnchorAction
}

enum BookmarkFeedIntegration {
    static func action(
        postID: String,
        isBookmarked: Bool,
        edges: [BookmarkEdge]
    ) -> BookmarkFeedPostContentAction {
        action(
            for: .bookmarkChanged(postID: postID, isBookmarked: isBookmarked),
            edges: edges,
            eventGeneration: 0,
            activeGeneration: 0
        )
    }

    static func action(
        for event: PostContentEvent,
        edges: [BookmarkEdge],
        eventGeneration: Int,
        activeGeneration: Int
    ) -> BookmarkFeedPostContentAction {
        switch event {
        case .bookmarkChanged(_, true):
            return .authoritativeRefresh
        case .replyCreated:
            return .none
        case .postDeleted, .bookmarkChanged(_, false):
            break
        }

        let action = PostContentListEventRouter.route(
            event,
            host: .bookmarks,
            rows: edges.map {
                postListItemIdentity(rowID: $0.node.id, post: $0.node)
            },
            eventGeneration: eventGeneration,
            activeGeneration: activeGeneration
        )
        guard case let .remove(nodeIDs) = action else { return .none }
        return .remove(nodeIDs: nodeIDs)
    }

    static func normalizedPage(_ incoming: [BookmarkEdge]) -> [BookmarkEdge] {
        BookmarkFeedIdentity.normalizedPage(incoming, id: { $0.node.id }).items
    }

    static func append(_ incoming: [BookmarkEdge], to existing: inout [BookmarkEdge]) {
        let newEdges = itemsExcludingKnownIDs(incoming, knownBy: existing)
        existing.append(contentsOf: newEdges)
    }

    static func mergingNewerPage(
        _ incoming: [BookmarkEdge],
        into existing: [BookmarkEdge],
        nextCursor: String?,
        hasNextPage: Bool
    ) -> BookmarkFeedNewerPageMerge {
        guard !incoming.isEmpty else {
            return BookmarkFeedNewerPageMerge(
                edges: existing,
                pendingNewerCursor: nil,
                hasPreviousPage: false,
                scrollAnchorAction: .none
            )
        }

        let edges = itemsExcludingKnownIDs(incoming, knownBy: existing) + existing
        return BookmarkFeedNewerPageMerge(
            edges: edges,
            pendingNewerCursor: hasNextPage ? nextCursor : nil,
            hasPreviousPage: hasNextPage && nextCursor != nil,
            scrollAnchorAction: edges.count > existing.count ? .restore : .reset
        )
    }

    static func applyScrollAnchorAction(
        for merge: BookmarkFeedNewerPageMerge,
        policy: inout FeedScrollAnchorPolicy<String>,
        restoration: inout FeedScrollAnchorPolicy<String>.Restoration?,
        viewport: FeedViewportSnapshot<String>,
        existing: [BookmarkEdge]
    ) {
        switch merge.scrollAnchorAction {
        case .none:
            return
        case .restore:
            policy.captureBeforePrepending(
                viewport: viewport,
                existingIDs: existing.map(\.node.id)
            )
            restoration = policy.takeRestoration(availableIDs: merge.edges.map(\.node.id))
        case .reset:
            policy.reset()
        }
    }

    private static func itemsExcludingKnownIDs(
        _ incoming: [BookmarkEdge],
        knownBy existing: [BookmarkEdge]
    ) -> [BookmarkEdge] {
        BookmarkFeedIdentity.itemsExcludingKnownIDs(
            incoming,
            knownIDs: Set(existing.map(\.node.id)),
            id: { $0.node.id }
        )
    }
}
