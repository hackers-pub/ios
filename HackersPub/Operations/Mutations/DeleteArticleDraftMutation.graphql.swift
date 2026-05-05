// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct DeleteArticleDraftMutation: GraphQLMutation {
    public static let operationName: String = "DeleteArticleDraftMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation DeleteArticleDraftMutation($id: ID!) { deleteArticleDraft(input: { id: $id }) { __typename ... on DeleteArticleDraftPayload { deletedDraftId } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
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
        .field("deleteArticleDraft", DeleteArticleDraft.self, arguments: ["input": ["id": .variable("id")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        DeleteArticleDraftMutation.Data.self
      ] }

      public var deleteArticleDraft: DeleteArticleDraft { __data["deleteArticleDraft"] }

      /// DeleteArticleDraft
      ///
      /// Parent Type: `DeleteArticleDraftResult`
      public struct DeleteArticleDraft: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.DeleteArticleDraftResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsDeleteArticleDraftPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          DeleteArticleDraftMutation.Data.DeleteArticleDraft.self
        ] }

        public var asDeleteArticleDraftPayload: AsDeleteArticleDraftPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// DeleteArticleDraft.AsDeleteArticleDraftPayload
        ///
        /// Parent Type: `DeleteArticleDraftPayload`
        public struct AsDeleteArticleDraftPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = DeleteArticleDraftMutation.Data.DeleteArticleDraft
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.DeleteArticleDraftPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("deletedDraftId", HackersPub.ID.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            DeleteArticleDraftMutation.Data.DeleteArticleDraft.self,
            DeleteArticleDraftMutation.Data.DeleteArticleDraft.AsDeleteArticleDraftPayload.self
          ] }

          public var deletedDraftId: HackersPub.ID { __data["deletedDraftId"] }
        }

        /// DeleteArticleDraft.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = DeleteArticleDraftMutation.Data.DeleteArticleDraft
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            DeleteArticleDraftMutation.Data.DeleteArticleDraft.self,
            DeleteArticleDraftMutation.Data.DeleteArticleDraft.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// DeleteArticleDraft.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = DeleteArticleDraftMutation.Data.DeleteArticleDraft
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            DeleteArticleDraftMutation.Data.DeleteArticleDraft.self,
            DeleteArticleDraftMutation.Data.DeleteArticleDraft.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}