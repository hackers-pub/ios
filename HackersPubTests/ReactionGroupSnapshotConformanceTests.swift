@_spi(Unsafe) import ApolloAPI
@testable import HackersPub
import Testing

private typealias PublicTimelineNode = HackersPub.PublicTimelineQuery.Data.PublicTimeline.Edge.Node
private typealias LocalTimelineNode = HackersPub.LocalTimelineQuery.Data.PublicTimeline.Edge.Node
private typealias PersonalTimelineNode = HackersPub.PersonalTimelineQuery.Data.PersonalTimeline.Edge.Node
private typealias SearchPostNode = HackersPub.SearchPostQuery.Data.SearchPost.Edge.Node
private typealias ActorPostsNode = HackersPub.ActorByHandleQuery.Data.ActorByHandle.Posts.Edge.Node
private typealias ActorNotesNode = HackersPub.ActorNotesQuery.Data.ActorByHandle.Notes.Edge.Node
private typealias ActorArticlesNode = HackersPub.ActorArticlesQuery.Data.ActorByHandle.Articles.Edge.Node
private typealias BookmarkNode = HackersPub.BookmarksQuery.Data.Bookmarks.Edge.Node
private typealias NewsSharingPostNode = HackersPub.NewsStoryDetailQuery.Data.NewsStory.SharingPosts.Edge.Node
private typealias PostDetailNode = HackersPub.PostDetailQuery.Data.Node.AsPost
private typealias PostReplyNode = HackersPub.PostDetailQuery.Data.Node.AsPost.Replies.Edge.Node
private typealias PostQuoteNode = HackersPub.PostQuotesQuery.Data.Node.AsPost.Quotes.Edge.Node
private typealias PublicGroup = PublicTimelineNode.ReactionGroup
private typealias LocalGroup = LocalTimelineNode.ReactionGroup
private typealias PersonalGroup = PersonalTimelineNode.ReactionGroup
private typealias SearchGroup = SearchPostNode.ReactionGroup
private typealias ActorPostsGroup = ActorPostsNode.ReactionGroup
private typealias ActorNotesGroup = ActorNotesNode.ReactionGroup
private typealias ActorArticlesGroup = ActorArticlesNode.ReactionGroup
private typealias BookmarkGroup = BookmarkNode.ReactionGroup
private typealias NewsSharingGroup = NewsSharingPostNode.ReactionGroup
private typealias PostDetailGroup = PostDetailNode.ReactionGroup
private typealias PostReplyGroup = PostReplyNode.ReactionGroup
private typealias PostQuoteGroup = PostQuoteNode.ReactionGroup

struct ReactionGroupSnapshotConformanceTests {
    @Test func timelineAndProfileReactionConformancesPreserveSnapshotSemantics() {
        assertSnapshots(
            PublicTimelineNode.self,
            group: PublicGroup.self,
            emoji: PublicGroup.AsEmojiReactionGroup.self,
            custom: PublicGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            LocalTimelineNode.self,
            group: LocalGroup.self,
            emoji: LocalGroup.AsEmojiReactionGroup.self,
            custom: LocalGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            PersonalTimelineNode.self,
            group: PersonalGroup.self,
            emoji: PersonalGroup.AsEmojiReactionGroup.self,
            custom: PersonalGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            SearchPostNode.self,
            group: SearchGroup.self,
            emoji: SearchGroup.AsEmojiReactionGroup.self,
            custom: SearchGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            ActorPostsNode.self,
            group: ActorPostsGroup.self,
            emoji: ActorPostsGroup.AsEmojiReactionGroup.self,
            custom: ActorPostsGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            ActorNotesNode.self,
            group: ActorNotesGroup.self,
            emoji: ActorNotesGroup.AsEmojiReactionGroup.self,
            custom: ActorNotesGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            ActorArticlesNode.self,
            group: ActorArticlesGroup.self,
            emoji: ActorArticlesGroup.AsEmojiReactionGroup.self,
            custom: ActorArticlesGroup.AsCustomEmojiReactionGroup.self
        )
    }

    @Test func bookmarkNewsAndDetailReactionConformancesPreserveSnapshotSemantics() {
        assertSnapshots(
            BookmarkNode.self,
            group: BookmarkGroup.self,
            emoji: BookmarkGroup.AsEmojiReactionGroup.self,
            custom: BookmarkGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            NewsSharingPostNode.self,
            group: NewsSharingGroup.self,
            emoji: NewsSharingGroup.AsEmojiReactionGroup.self,
            custom: NewsSharingGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            PostDetailNode.self,
            group: PostDetailGroup.self,
            emoji: PostDetailGroup.AsEmojiReactionGroup.self,
            custom: PostDetailGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            PostReplyNode.self,
            group: PostReplyGroup.self,
            emoji: PostReplyGroup.AsEmojiReactionGroup.self,
            custom: PostReplyGroup.AsCustomEmojiReactionGroup.self
        )
        assertSnapshots(
            PostQuoteNode.self,
            group: PostQuoteGroup.self,
            emoji: PostQuoteGroup.AsEmojiReactionGroup.self,
            custom: PostQuoteGroup.AsCustomEmojiReactionGroup.self
        )
    }

    private func assertSnapshots<
        Node: ApolloAPI.SelectionSet & ReactionCapablePostProtocol,
        Group: HackersPub.SelectionSet,
        Emoji: HackersPub.InlineFragment,
        Custom: HackersPub.InlineFragment
    >(
        _ nodeType: Node.Type,
        group: Group.Type,
        emoji: Emoji.Type,
        custom: Custom.Type
    ) {
        let node = Node(_dataDict: DataDict(
            data: [
                "reactionGroups": [
                    emojiGroup(group: group, emoji: emoji),
                    rawGroup(group: group),
                    customGroup(group: group, custom: custom)
                ]
            ],
            fulfilledFragments: [ObjectIdentifier(nodeType)]
        ))

        #expect(node.reactionGroupsSnapshot == expectedSnapshots)
    }

    private var expectedSnapshots: [ReactionGroupSnapshot] {
        [
            ReactionGroupSnapshot(
                id: "emoji:🎉",
                emoji: "🎉",
                customEmojiName: nil,
                customEmojiImageUrl: nil,
                totalCount: 7,
                viewerHasReacted: true
            ),
            ReactionGroupSnapshot(
                id: "custom:party-parrot",
                emoji: nil,
                customEmojiName: "party_parrot",
                customEmojiImageUrl: "https://example.com/party-parrot.png",
                totalCount: 2,
                viewerHasReacted: false
            )
        ]
    }

    private func emojiGroup<
        Group: HackersPub.SelectionSet,
        Emoji: HackersPub.InlineFragment
    >(
        group: Group.Type,
        emoji: Emoji.Type
    ) -> DataDict {
        DataDict(
            data: [
                "__typename": "EmojiReactionGroup",
                "emoji": "🎉",
                "reactors": reactors(totalCount: 7, viewerHasReacted: true)
            ],
            fulfilledFragments: [ObjectIdentifier(group), ObjectIdentifier(emoji)]
        )
    }

    private func customGroup<
        Group: HackersPub.SelectionSet,
        Custom: HackersPub.InlineFragment
    >(
        group: Group.Type,
        custom: Custom.Type
    ) -> DataDict {
        DataDict(
            data: [
                "__typename": "CustomEmojiReactionGroup",
                "customEmoji": DataDict(
                    data: [
                        "__typename": "CustomEmoji",
                        "id": "party-parrot",
                        "name": "party_parrot",
                        "imageUrl": "https://example.com/party-parrot.png"
                    ],
                    fulfilledFragments: []
                ),
                "reactors": reactors(totalCount: 2, viewerHasReacted: false)
            ],
            fulfilledFragments: [ObjectIdentifier(group), ObjectIdentifier(custom)]
        )
    }

    private func rawGroup<Group: HackersPub.SelectionSet>(group: Group.Type) -> DataDict {
        DataDict(
            data: ["__typename": "UnknownReactionGroup"],
            fulfilledFragments: [ObjectIdentifier(group)]
        )
    }

    private func reactors(totalCount: Int, viewerHasReacted: Bool) -> DataDict {
        DataDict(
            data: [
                "__typename": "ReactionGroupReactorsConnection",
                "totalCount": totalCount,
                "viewerHasReacted": viewerHasReacted
            ],
            fulfilledFragments: []
        )
    }
}
