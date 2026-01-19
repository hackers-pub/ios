// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct SharePostMutation: GraphQLMutation {
    public static let operationName: String = "SharePostMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation SharePostMutation($postId: ID!) { sharePost(input: { postId: $postId }) { __typename ... on SharePostPayload { originalPost { __typename id viewerHasShared engagementStats { __typename replies reactions shares quotes } } share { __typename id } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var postId: ID

    public init(postId: ID) {
      self.postId = postId
    }

    @_spi(Unsafe) public var __variables: Variables? { ["postId": postId] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("sharePost", SharePost.self, arguments: ["input": ["postId": .variable("postId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        SharePostMutation.Data.self
      ] }

      public var sharePost: SharePost { __data["sharePost"] }

      /// SharePost
      ///
      /// Parent Type: `SharePostResult`
      public struct SharePost: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.SharePostResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsSharePostPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          SharePostMutation.Data.SharePost.self
        ] }

        public var asSharePostPayload: AsSharePostPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// SharePost.AsSharePostPayload
        ///
        /// Parent Type: `SharePostPayload`
        public struct AsSharePostPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SharePostMutation.Data.SharePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.SharePostPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("originalPost", OriginalPost.self),
            .field("share", Share.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SharePostMutation.Data.SharePost.self,
            SharePostMutation.Data.SharePost.AsSharePostPayload.self
          ] }

          public var originalPost: OriginalPost { __data["originalPost"] }
          public var share: Share { __data["share"] }

          /// SharePost.AsSharePostPayload.OriginalPost
          ///
          /// Parent Type: `Post`
          public struct OriginalPost: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("viewerHasShared", Bool.self),
              .field("engagementStats", EngagementStats.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              SharePostMutation.Data.SharePost.AsSharePostPayload.OriginalPost.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var viewerHasShared: Bool { __data["viewerHasShared"] }
            public var engagementStats: EngagementStats { __data["engagementStats"] }

            /// SharePost.AsSharePostPayload.OriginalPost.EngagementStats
            ///
            /// Parent Type: `PostEngagementStats`
            public struct EngagementStats: HackersPub.SelectionSet {
              @_spi(Unsafe) public let __data: DataDict
              @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

              @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.PostEngagementStats }
              @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
                .field("__typename", String.self),
                .field("replies", Int.self),
                .field("reactions", Int.self),
                .field("shares", Int.self),
                .field("quotes", Int.self),
              ] }
              @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
                SharePostMutation.Data.SharePost.AsSharePostPayload.OriginalPost.EngagementStats.self
              ] }

              public var replies: Int { __data["replies"] }
              public var reactions: Int { __data["reactions"] }
              public var shares: Int { __data["shares"] }
              public var quotes: Int { __data["quotes"] }
            }
          }

          /// SharePost.AsSharePostPayload.Share
          ///
          /// Parent Type: `Post`
          public struct Share: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              SharePostMutation.Data.SharePost.AsSharePostPayload.Share.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }
        }

        /// SharePost.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SharePostMutation.Data.SharePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SharePostMutation.Data.SharePost.self,
            SharePostMutation.Data.SharePost.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// SharePost.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SharePostMutation.Data.SharePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SharePostMutation.Data.SharePost.self,
            SharePostMutation.Data.SharePost.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}