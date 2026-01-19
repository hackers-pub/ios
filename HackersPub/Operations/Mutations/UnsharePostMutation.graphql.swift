// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct UnsharePostMutation: GraphQLMutation {
    public static let operationName: String = "UnsharePostMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation UnsharePostMutation($postId: ID!) { unsharePost(input: { postId: $postId }) { __typename ... on UnsharePostPayload { originalPost { __typename id viewerHasShared engagementStats { __typename replies reactions shares quotes } } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
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
        .field("unsharePost", UnsharePost.self, arguments: ["input": ["postId": .variable("postId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        UnsharePostMutation.Data.self
      ] }

      public var unsharePost: UnsharePost { __data["unsharePost"] }

      /// UnsharePost
      ///
      /// Parent Type: `UnsharePostResult`
      public struct UnsharePost: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.UnsharePostResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsUnsharePostPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          UnsharePostMutation.Data.UnsharePost.self
        ] }

        public var asUnsharePostPayload: AsUnsharePostPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// UnsharePost.AsUnsharePostPayload
        ///
        /// Parent Type: `UnsharePostPayload`
        public struct AsUnsharePostPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnsharePostMutation.Data.UnsharePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.UnsharePostPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("originalPost", OriginalPost.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnsharePostMutation.Data.UnsharePost.self,
            UnsharePostMutation.Data.UnsharePost.AsUnsharePostPayload.self
          ] }

          public var originalPost: OriginalPost { __data["originalPost"] }

          /// UnsharePost.AsUnsharePostPayload.OriginalPost
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
              UnsharePostMutation.Data.UnsharePost.AsUnsharePostPayload.OriginalPost.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var viewerHasShared: Bool { __data["viewerHasShared"] }
            public var engagementStats: EngagementStats { __data["engagementStats"] }

            /// UnsharePost.AsUnsharePostPayload.OriginalPost.EngagementStats
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
                UnsharePostMutation.Data.UnsharePost.AsUnsharePostPayload.OriginalPost.EngagementStats.self
              ] }

              public var replies: Int { __data["replies"] }
              public var reactions: Int { __data["reactions"] }
              public var shares: Int { __data["shares"] }
              public var quotes: Int { __data["quotes"] }
            }
          }
        }

        /// UnsharePost.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnsharePostMutation.Data.UnsharePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnsharePostMutation.Data.UnsharePost.self,
            UnsharePostMutation.Data.UnsharePost.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// UnsharePost.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnsharePostMutation.Data.UnsharePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnsharePostMutation.Data.UnsharePost.self,
            UnsharePostMutation.Data.UnsharePost.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}