// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct StartMediumUploadMutation: GraphQLMutation {
    public static let operationName: String = "StartMediumUploadMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation StartMediumUploadMutation($contentType: MediaType!, $contentLength: Int!) { startMediumUpload( input: { contentType: $contentType, contentLength: $contentLength } ) { __typename ... on StartMediumUploadPayload { uploadId uploadUrl method headers { __typename name value } expires } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var contentType: MediaType
    public var contentLength: Int32

    public init(
      contentType: MediaType,
      contentLength: Int32
    ) {
      self.contentType = contentType
      self.contentLength = contentLength
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "contentType": contentType,
      "contentLength": contentLength
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("startMediumUpload", StartMediumUpload.self, arguments: ["input": [
          "contentType": .variable("contentType"),
          "contentLength": .variable("contentLength")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        StartMediumUploadMutation.Data.self
      ] }

      public var startMediumUpload: StartMediumUpload { __data["startMediumUpload"] }

      /// StartMediumUpload
      ///
      /// Parent Type: `StartMediumUploadResult`
      public struct StartMediumUpload: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.StartMediumUploadResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsStartMediumUploadPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          StartMediumUploadMutation.Data.StartMediumUpload.self
        ] }

        public var asStartMediumUploadPayload: AsStartMediumUploadPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// StartMediumUpload.AsStartMediumUploadPayload
        ///
        /// Parent Type: `StartMediumUploadPayload`
        public struct AsStartMediumUploadPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = StartMediumUploadMutation.Data.StartMediumUpload
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.StartMediumUploadPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("uploadId", HackersPub.UUID.self),
            .field("uploadUrl", HackersPub.URL.self),
            .field("method", String.self),
            .field("headers", [Header].self),
            .field("expires", HackersPub.DateTime.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            StartMediumUploadMutation.Data.StartMediumUpload.self,
            StartMediumUploadMutation.Data.StartMediumUpload.AsStartMediumUploadPayload.self
          ] }

          public var uploadId: HackersPub.UUID { __data["uploadId"] }
          public var uploadUrl: HackersPub.URL { __data["uploadUrl"] }
          public var method: String { __data["method"] }
          public var headers: [Header] { __data["headers"] }
          public var expires: HackersPub.DateTime { __data["expires"] }

          /// StartMediumUpload.AsStartMediumUploadPayload.Header
          ///
          /// Parent Type: `MediumUploadHeader`
          public struct Header: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.MediumUploadHeader }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("name", String.self),
              .field("value", String.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              StartMediumUploadMutation.Data.StartMediumUpload.AsStartMediumUploadPayload.Header.self
            ] }

            public var name: String { __data["name"] }
            public var value: String { __data["value"] }
          }
        }

        /// StartMediumUpload.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = StartMediumUploadMutation.Data.StartMediumUpload
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            StartMediumUploadMutation.Data.StartMediumUpload.self,
            StartMediumUploadMutation.Data.StartMediumUpload.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// StartMediumUpload.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = StartMediumUploadMutation.Data.StartMediumUpload
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            StartMediumUploadMutation.Data.StartMediumUpload.self,
            StartMediumUploadMutation.Data.StartMediumUpload.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}