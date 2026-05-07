// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct AttachArticleDraftMediumMutation: GraphQLMutation {
    public static let operationName: String = "AttachArticleDraftMediumMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation AttachArticleDraftMediumMutation($draftId: UUID!, $mediumId: UUID!, $key: String) { attachArticleDraftMedium( input: { draftId: $draftId, mediumId: $mediumId, key: $key } ) { __typename ... on AttachArticleDraftMediumPayload { __typename } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var draftId: UUID
    public var mediumId: UUID
    public var key: GraphQLNullable<String>

    public init(
      draftId: UUID,
      mediumId: UUID,
      key: GraphQLNullable<String>
    ) {
      self.draftId = draftId
      self.mediumId = mediumId
      self.key = key
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "draftId": draftId,
      "mediumId": mediumId,
      "key": key
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("attachArticleDraftMedium", AttachArticleDraftMedium.self, arguments: ["input": [
          "draftId": .variable("draftId"),
          "mediumId": .variable("mediumId"),
          "key": .variable("key")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        AttachArticleDraftMediumMutation.Data.self
      ] }

      public var attachArticleDraftMedium: AttachArticleDraftMedium { __data["attachArticleDraftMedium"] }

      /// AttachArticleDraftMedium
      ///
      /// Parent Type: `AttachArticleDraftMediumResult`
      public struct AttachArticleDraftMedium: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.AttachArticleDraftMediumResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsAttachArticleDraftMediumPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium.self
        ] }

        public var asAttachArticleDraftMediumPayload: AsAttachArticleDraftMediumPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// AttachArticleDraftMedium.AsAttachArticleDraftMediumPayload
        ///
        /// Parent Type: `AttachArticleDraftMediumPayload`
        public struct AsAttachArticleDraftMediumPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.AttachArticleDraftMediumPayload }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium.self,
            AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium.AsAttachArticleDraftMediumPayload.self
          ] }
        }

        /// AttachArticleDraftMedium.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium.self,
            AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// AttachArticleDraftMedium.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium.self,
            AttachArticleDraftMediumMutation.Data.AttachArticleDraftMedium.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}