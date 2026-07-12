import Foundation

enum BookmarkFeedIdentity {
    struct NormalizedPage<Item> {
        let items: [Item]
        let paginationTriggerID: String?
    }

    static func normalizedPage<Item>(
        _ incoming: [Item],
        id: (Item) -> String
    ) -> NormalizedPage<Item> {
        let items = itemsExcludingKnownIDs(incoming, knownIDs: [], id: id)
        return NormalizedPage(items: items, paginationTriggerID: items.last.map(id))
    }

    /// Keeps server order while using the same post ID identity as the view.
    static func itemsExcludingKnownIDs<Item>(
        _ incoming: [Item],
        knownIDs: Set<String>,
        id: (Item) -> String
    ) -> [Item] {
        var seenIDs = knownIDs
        return incoming.filter { item in
            seenIDs.insert(id(item)).inserted
        }
    }
}
