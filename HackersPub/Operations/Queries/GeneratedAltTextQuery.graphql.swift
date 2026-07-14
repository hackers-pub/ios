// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct GeneratedAltTextQuery: GraphQLQuery {
    public static let operationName: String = "GeneratedAltTextQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query GeneratedAltTextQuery($id: ID!, $language: Locale!, $context: String) { node(id: $id) { __typename ... on Medium { generatedAltText(language: $language, context: $context) } } }"#
      ))

    public var id: ID
    public var language: Locale
    public var context: GraphQLNullable<String>

    public init(
      id: ID,
      language: Locale,
      context: GraphQLNullable<String>
    ) {
      self.id = id
      self.language = language
      self.context = context
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "id": id,
      "language": language,
      "context": context
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("node", Node?.self, arguments: ["id": .variable("id")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        GeneratedAltTextQuery.Data.self
      ] }

      public var node: Node? { __data["node"] }

      /// Node
      ///
      /// Parent Type: `Node`
      public struct Node: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Interfaces.Node }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsMedium.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          GeneratedAltTextQuery.Data.Node.self
        ] }

        public var asMedium: AsMedium? { _asInlineFragment() }

        /// Node.AsMedium
        ///
        /// Parent Type: `Medium`
        public struct AsMedium: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = GeneratedAltTextQuery.Data.Node
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Medium }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("generatedAltText", String?.self, arguments: [
              "language": .variable("language"),
              "context": .variable("context")
            ]),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            GeneratedAltTextQuery.Data.Node.self,
            GeneratedAltTextQuery.Data.Node.AsMedium.self
          ] }

          /// AI-generated alternative text for this medium. Requires authentication. Within the 2-hour upload window only the uploader may call this field; after the window expires any authenticated user may call it (the medium is either publicly referenced or pending orphan cleanup). Multiple uploaders of identical content each get independent ownership entries, so content-hash deduplication does not grant the later uploader access to the earlier one's window. High-complexity operation (cost 1000). The context argument is truncated server-side to 1000 characters.
          public var generatedAltText: String? { __data["generatedAltText"] }
        }
      }
    }
  }

}