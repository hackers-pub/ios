// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct DeletePostMutation: GraphQLMutation {
    public static let operationName: String = "DeletePostMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation DeletePostMutation($id: ID!) { deletePost(input: { id: $id }) { __typename ... on DeletePostPayload { deletedPostId } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } ... on SharedPostDeletionNotAllowedError { inputPath } } }"#
      ))

    public var id: ID

    public init(id: ID) {
      self.id = id
    }

    @_spi(Unsafe) public var __variables: Variables? { ["id": id] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("deletePost", DeletePost.self, arguments: ["input": ["id": .variable("id")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        DeletePostMutation.Data.self
      ] }

      public var deletePost: DeletePost { __data["deletePost"] }

      /// DeletePost
      ///
      /// Parent Type: `DeletePostResult`
      public struct DeletePost: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.DeletePostResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsDeletePostPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
          .inlineFragment(AsSharedPostDeletionNotAllowedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          DeletePostMutation.Data.DeletePost.self
        ] }

        public var asDeletePostPayload: AsDeletePostPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }
        public var asSharedPostDeletionNotAllowedError: AsSharedPostDeletionNotAllowedError? { _asInlineFragment() }

        /// DeletePost.AsDeletePostPayload
        ///
        /// Parent Type: `DeletePostPayload`
        public struct AsDeletePostPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = DeletePostMutation.Data.DeletePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.DeletePostPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("deletedPostId", HackersPub.ID.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            DeletePostMutation.Data.DeletePost.self,
            DeletePostMutation.Data.DeletePost.AsDeletePostPayload.self
          ] }

          public var deletedPostId: HackersPub.ID { __data["deletedPostId"] }
        }

        /// DeletePost.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = DeletePostMutation.Data.DeletePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            DeletePostMutation.Data.DeletePost.self,
            DeletePostMutation.Data.DeletePost.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// DeletePost.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = DeletePostMutation.Data.DeletePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            DeletePostMutation.Data.DeletePost.self,
            DeletePostMutation.Data.DeletePost.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }

        /// DeletePost.AsSharedPostDeletionNotAllowedError
        ///
        /// Parent Type: `SharedPostDeletionNotAllowedError`
        public struct AsSharedPostDeletionNotAllowedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = DeletePostMutation.Data.DeletePost
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.SharedPostDeletionNotAllowedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            DeletePostMutation.Data.DeletePost.self,
            DeletePostMutation.Data.DeletePost.AsSharedPostDeletionNotAllowedError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }
      }
    }
  }

}