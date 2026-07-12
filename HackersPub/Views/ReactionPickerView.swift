import Foundation

let supportedReactionEmojis = ["❤️", "🎉", "😂", "😲", "🤔", "😢", "👀"]

enum ReactionL10n {
    static let title = NSLocalizedString("reaction.title", comment: "Reactions title")
    static let react = NSLocalizedString("reaction.action.react", comment: "React action")
    static let failedTitle = NSLocalizedString("reaction.error.title", comment: "Reaction error title")
    static let signInRequired = NSLocalizedString(
        "reaction.error.signInRequired",
        comment: "Sign in required to react message"
    )
    static let unableToAdd = NSLocalizedString(
        "reaction.error.unableToAdd",
        comment: "Unable to add reaction message"
    )
    static let unableToRemove = NSLocalizedString(
        "reaction.error.unableToRemove",
        comment: "Unable to remove reaction message"
    )
    static let close = NSLocalizedString("reaction.action.close", comment: "Close reaction picker")
    static let reactedWithFormat = NSLocalizedString(
        "reaction.reactors.titleFormat",
        comment: "Navigation title format for reacted users list"
    )
}

struct ReactionGroupSnapshot: Identifiable, Hashable {
    let id: String
    let emoji: String?
    let customEmojiName: String?
    let customEmojiImageUrl: String?
    var totalCount: Int
    var viewerHasReacted: Bool
}

enum ReactionGroupIndex {
    static func standardGroupsByEmoji(
        _ groups: [ReactionGroupSnapshot]
    ) -> [String: ReactionGroupSnapshot] {
        let rawGroups = aggregateRawEmojiGroups(groups)
        return Dictionary(grouping: rawGroups, by: { canonicalEmojiKey($0.emoji ?? "") })
            .mapValues(mergeCanonicalVariants)
    }

    static func viewerHasReacted(
        to emoji: String,
        in groups: [ReactionGroupSnapshot]
    ) -> Bool {
        standardGroup(matching: emoji, in: groups)?.viewerHasReacted == true
    }

    static func standardGroup(
        matching emoji: String,
        in groups: [ReactionGroupSnapshot]
    ) -> ReactionGroupSnapshot? {
        standardGroupsByEmoji(groups)[canonicalEmojiKey(emoji)]
    }

    static func isEquivalentStandardEmoji(_ lhs: String, _ rhs: String) -> Bool {
        canonicalEmojiKey(lhs) == canonicalEmojiKey(rhs)
    }

    static func mutationEmoji(
        for emoji: String,
        in groups: [ReactionGroupSnapshot]
    ) -> String {
        standardGroup(matching: emoji, in: groups)?.emoji ?? emoji
    }

    private static func canonicalEmojiKey(_ emoji: String) -> String {
        let key = removingPresentationSelectors(from: emoji)
        return supportedReactionEmojis.first {
            removingPresentationSelectors(from: $0) == key
        } ?? key
    }

    private static func removingPresentationSelectors(from emoji: String) -> String {
        emoji
            .replacingOccurrences(of: "\u{FE0E}", with: "")
            .replacingOccurrences(of: "\u{FE0F}", with: "")
    }

    private static func aggregateRawEmojiGroups(
        _ groups: [ReactionGroupSnapshot]
    ) -> [ReactionGroupSnapshot] {
        let grouped = Dictionary(grouping: groups.compactMap { group -> ReactionGroupSnapshot? in
            group.emoji == nil ? nil : group
        }, by: { $0.emoji ?? "" })
        return grouped.keys.sorted().compactMap { rawEmoji in
            grouped[rawEmoji].map(mergeExactRawVariants)
        }
    }

    private static func mergeExactRawVariants(
        _ variants: [ReactionGroupSnapshot]
    ) -> ReactionGroupSnapshot {
        var merged = variants.sorted(by: rawVariantSort)[0]
        merged.totalCount = variants.reduce(0) { $0 + max(0, $1.totalCount) }
        merged.viewerHasReacted = variants.contains(where: \.viewerHasReacted)
        return merged
    }

    private static func mergeCanonicalVariants(
        _ variants: [ReactionGroupSnapshot]
    ) -> ReactionGroupSnapshot {
        let sorted = variants.sorted(by: rawVariantSort)
        let viewerVariants = sorted.filter(\.viewerHasReacted)
        var merged = (viewerVariants.first ?? sorted[0])
        merged.totalCount = sorted.reduce(0) { $0 + max(0, $1.totalCount) }
        merged.viewerHasReacted = !viewerVariants.isEmpty
        return merged
    }

    private static func rawVariantSort(
        _ lhs: ReactionGroupSnapshot,
        _ rhs: ReactionGroupSnapshot
    ) -> Bool {
        let lhsEmoji = lhs.emoji ?? ""
        let rhsEmoji = rhs.emoji ?? ""
        if lhsEmoji != rhsEmoji {
            return lhsEmoji < rhsEmoji
        }
        return lhs.id < rhs.id
    }
}

protocol ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] { get }
}
