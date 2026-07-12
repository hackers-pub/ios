@preconcurrency import Apollo
import Foundation

enum BookmarkFilter: String, CaseIterable, Identifiable {
    case all
    case articles
    case notes

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            NSLocalizedString("bookmarks.filter.all", comment: "All bookmarks filter")
        case .articles:
            NSLocalizedString("bookmarks.filter.articles", comment: "Article bookmarks filter")
        case .notes:
            NSLocalizedString("bookmarks.filter.notes", comment: "Note bookmarks filter")
        }
    }

    var postType: GraphQLNullable<GraphQLEnum<HackersPub.PostType>> {
        switch self {
        case .all:
            nil
        case .articles:
            .some(.case(.article))
        case .notes:
            .some(.case(.note))
        }
    }
}
