// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct UnbookmarkPostMutation: GraphQLMutation {
    public static let operationName: String = "UnbookmarkPostMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation UnbookmarkPostMutation($postId: ID!) { unbookmarkPost(input: { postId: $postId }) { __typename ... on UnbookmarkPostPayload { post { __typename id viewerHasBookmarked } unbookmarkedPostId } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
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
        .field("unbookmarkPost", UnbookmarkPost.self, arguments: ["input": ["postId": .variable("postId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        UnbookmarkPostMutation.Data.self
      ] }

      public var unbookmarkPost: UnbookmarkPost { __data["unbookmarkPost"] }

      /// UnbookmarkPost
      ///
      /// Parent Type: `UnbookmarkPostResult`
      public struct UnbookmarkPost: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.UnbookmarkPostResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsUnbookmarkPostPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          UnbookmarkPostMutation.Data.UnbookmarkPost.self
        ] }

        public var asUnbookmarkPostPayload: AsUnbookmarkPostPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// UnbookmarkPost.AsUnbookmarkPostPayload
        ///
        /// Parent Type: `UnbookmarkPostPayload`
        public struct AsUnbookmarkPostPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnbookmarkPostMutation.Data.UnbookmarkPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.UnbookmarkPostPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("post", Post.self),
            .field("unbookmarkedPostId", HackersPub.ID.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnbookmarkPostMutation.Data.UnbookmarkPost.self,
            UnbookmarkPostMutation.Data.UnbookmarkPost.AsUnbookmarkPostPayload.self
          ] }

          public var post: Post { __data["post"] }
          public var unbookmarkedPostId: HackersPub.ID { __data["unbookmarkedPostId"] }

          /// UnbookmarkPost.AsUnbookmarkPostPayload.Post
          ///
          /// Parent Type: `Post`
          public struct Post: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Post }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("viewerHasBookmarked", Bool.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              UnbookmarkPostMutation.Data.UnbookmarkPost.AsUnbookmarkPostPayload.Post.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            /// Whether the authenticated viewer has bookmarked this post. Always `false` for unauthenticated requests.
            public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
          }
        }

        /// UnbookmarkPost.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnbookmarkPostMutation.Data.UnbookmarkPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnbookmarkPostMutation.Data.UnbookmarkPost.self,
            UnbookmarkPostMutation.Data.UnbookmarkPost.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// UnbookmarkPost.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = UnbookmarkPostMutation.Data.UnbookmarkPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            UnbookmarkPostMutation.Data.UnbookmarkPost.self,
            UnbookmarkPostMutation.Data.UnbookmarkPost.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}