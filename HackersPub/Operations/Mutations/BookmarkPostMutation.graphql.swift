// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct BookmarkPostMutation: GraphQLMutation {
    public static let operationName: String = "BookmarkPostMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation BookmarkPostMutation($postId: ID!) { bookmarkPost(input: { postId: $postId }) { __typename ... on BookmarkPostPayload { post { __typename id viewerHasBookmarked } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
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
        .field("bookmarkPost", BookmarkPost.self, arguments: ["input": ["postId": .variable("postId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        BookmarkPostMutation.Data.self
      ] }

      public var bookmarkPost: BookmarkPost { __data["bookmarkPost"] }

      /// BookmarkPost
      ///
      /// Parent Type: `BookmarkPostResult`
      public struct BookmarkPost: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.BookmarkPostResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsBookmarkPostPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          BookmarkPostMutation.Data.BookmarkPost.self
        ] }

        public var asBookmarkPostPayload: AsBookmarkPostPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// BookmarkPost.AsBookmarkPostPayload
        ///
        /// Parent Type: `BookmarkPostPayload`
        public struct AsBookmarkPostPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = BookmarkPostMutation.Data.BookmarkPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.BookmarkPostPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("post", Post.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            BookmarkPostMutation.Data.BookmarkPost.self,
            BookmarkPostMutation.Data.BookmarkPost.AsBookmarkPostPayload.self
          ] }

          public var post: Post { __data["post"] }

          /// BookmarkPost.AsBookmarkPostPayload.Post
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
              BookmarkPostMutation.Data.BookmarkPost.AsBookmarkPostPayload.Post.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var viewerHasBookmarked: Bool { __data["viewerHasBookmarked"] }
          }
        }

        /// BookmarkPost.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = BookmarkPostMutation.Data.BookmarkPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            BookmarkPostMutation.Data.BookmarkPost.self,
            BookmarkPostMutation.Data.BookmarkPost.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// BookmarkPost.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = BookmarkPostMutation.Data.BookmarkPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            BookmarkPostMutation.Data.BookmarkPost.self,
            BookmarkPostMutation.Data.BookmarkPost.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}