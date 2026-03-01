// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct AddReactionToPostMutation: GraphQLMutation {
    public static let operationName: String = "AddReactionToPostMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation AddReactionToPostMutation($postId: ID!, $emoji: String!) { addReactionToPost(input: { postId: $postId, emoji: $emoji }) { __typename ... on AddReactionToPostPayload { reaction { __typename id } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
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
        .field("addReactionToPost", AddReactionToPost.self, arguments: ["input": [
          "postId": .variable("postId"),
          "emoji": .variable("emoji")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        AddReactionToPostMutation.Data.self
      ] }

      public var addReactionToPost: AddReactionToPost { __data["addReactionToPost"] }

      /// AddReactionToPost
      ///
      /// Parent Type: `AddReactionToPostResult`
      public struct AddReactionToPost: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.AddReactionToPostResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsAddReactionToPostPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          AddReactionToPostMutation.Data.AddReactionToPost.self
        ] }

        public var asAddReactionToPostPayload: AsAddReactionToPostPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// AddReactionToPost.AsAddReactionToPostPayload
        ///
        /// Parent Type: `AddReactionToPostPayload`
        public struct AsAddReactionToPostPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AddReactionToPostMutation.Data.AddReactionToPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AddReactionToPostPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("reaction", Reaction?.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AddReactionToPostMutation.Data.AddReactionToPost.self,
            AddReactionToPostMutation.Data.AddReactionToPost.AsAddReactionToPostPayload.self
          ] }

          public var reaction: Reaction? { __data["reaction"] }

          /// AddReactionToPost.AsAddReactionToPostPayload.Reaction
          ///
          /// Parent Type: `Reaction`
          public struct Reaction: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Reaction }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              AddReactionToPostMutation.Data.AddReactionToPost.AsAddReactionToPostPayload.Reaction.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
          }
        }

        /// AddReactionToPost.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AddReactionToPostMutation.Data.AddReactionToPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AddReactionToPostMutation.Data.AddReactionToPost.self,
            AddReactionToPostMutation.Data.AddReactionToPost.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// AddReactionToPost.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AddReactionToPostMutation.Data.AddReactionToPost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AddReactionToPostMutation.Data.AddReactionToPost.self,
            AddReactionToPostMutation.Data.AddReactionToPost.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}