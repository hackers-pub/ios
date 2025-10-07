// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct SearchObjectQuery: GraphQLQuery {
    public static let operationName: String = "SearchObjectQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query SearchObjectQuery($query: String!) { searchObject(query: $query) { __typename ... on SearchedObject { url } ... on EmptySearchQueryError { message } } }"#
      ))

    public var query: String

    public init(query: String) {
      self.query = query
    }

    @_spi(Unsafe) public var __variables: Variables? { ["query": query] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("searchObject", SearchObject?.self, arguments: ["query": .variable("query")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        SearchObjectQuery.Data.self
      ] }

      public var searchObject: SearchObject? { __data["searchObject"] }

      /// SearchObject
      ///
      /// Parent Type: `SearchObjectResult`
      public struct SearchObject: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.SearchObjectResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsSearchedObject.self),
          .inlineFragment(AsEmptySearchQueryError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          SearchObjectQuery.Data.SearchObject.self
        ] }

        public var asSearchedObject: AsSearchedObject? { _asInlineFragment() }
        public var asEmptySearchQueryError: AsEmptySearchQueryError? { _asInlineFragment() }

        /// SearchObject.AsSearchedObject
        ///
        /// Parent Type: `SearchedObject`
        public struct AsSearchedObject: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SearchObjectQuery.Data.SearchObject
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.SearchedObject }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("url", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SearchObjectQuery.Data.SearchObject.self,
            SearchObjectQuery.Data.SearchObject.AsSearchedObject.self
          ] }

          public var url: String { __data["url"] }
        }

        /// SearchObject.AsEmptySearchQueryError
        ///
        /// Parent Type: `EmptySearchQueryError`
        public struct AsEmptySearchQueryError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = SearchObjectQuery.Data.SearchObject
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.EmptySearchQueryError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("message", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            SearchObjectQuery.Data.SearchObject.self,
            SearchObjectQuery.Data.SearchObject.AsEmptySearchQueryError.self
          ] }

          public var message: String { __data["message"] }
        }
      }
    }
  }

}