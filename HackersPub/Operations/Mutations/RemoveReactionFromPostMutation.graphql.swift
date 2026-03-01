// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct RemoveReactionFromPostMutation: GraphQLMutation {
    public static let operationName: String = "RemoveReactionFromPostMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation RemoveReactionFromPostMutation($postId: ID!, $emoji: String!) { removeReactionFromPost(input: { postId: $postId, emoji: $emoji }) { __typename ... on RemoveReactionFromPostPayload { success } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var postId: ID
    public var emoji: String

    public init(
      postId: ID,
      emoji: String
    ) {
      self.postId = postId
      self.emoji = emoji
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "postId": postId,
      "emoji": emoji
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("removeReactionFromPost", RemoveReactionFromPost.self, arguments: ["input": [
          "postId": .variable("postId"),
          "emoji": .variable("emoji")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        RemoveReactionFromPostMutation.Data.self
      ] }

      public var removeReactionFromPost: RemoveReactionFromPost { __data["removeReactionFromPost"] }

      /// RemoveReactionFromPost
      ///
      /// Parent Type: `RemoveReactionFromPostResult`
      public struct RemoveReactionFromPost: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.RemoveReactionFromPostResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsRemoveReactionFromPostPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          RemoveReactionFromPostMutation.Data.RemoveReactionFromPost.self
        ] }

        public var asRemoveReactionFromPostPayload: AsRemoveReactionFromPostPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// RemoveReactionFromPost.AsRemoveReactionFromPostPayload
        ///
        /// Parent Type: `RemoveReactionFromPostPayload`
        public struct AsRemoveReactionFromPostPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RemoveReactionFromPostMutation.Data.RemoveReactionFromPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.RemoveReactionFromPostPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("success", Bool.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RemoveReactionFromPostMutation.Data.RemoveReactionFromPost.self,
            RemoveReactionFromPostMutation.Data.RemoveReactionFromPost.AsRemoveReactionFromPostPayload.self
          ] }

          public var success: Bool { __data["success"] }
        }

        /// RemoveReactionFromPost.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RemoveReactionFromPostMutation.Data.RemoveReactionFromPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RemoveReactionFromPostMutation.Data.RemoveReactionFromPost.self,
            RemoveReactionFromPostMutation.Data.RemoveReactionFromPost.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// RemoveReactionFromPost.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = RemoveReactionFromPostMutation.Data.RemoveReactionFromPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            RemoveReactionFromPostMutation.Data.RemoveReactionFromPost.self,
            RemoveReactionFromPostMutation.Data.RemoveReactionFromPost.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}