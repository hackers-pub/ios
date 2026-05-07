// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct FinishMediumUploadMutation: GraphQLMutation {
    public static let operationName: String = "FinishMediumUploadMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation FinishMediumUploadMutation($uploadId: UUID!) { finishMediumUpload(input: { uploadId: $uploadId }) { __typename ... on FinishMediumUploadPayload { medium { __typename uuid url type width height contentHash } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var uploadId: UUID

    public init(uploadId: UUID) {
      self.uploadId = uploadId
    }

    @_spi(Unsafe) public var __variables: Variables? { ["uploadId": uploadId] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("finishMediumUpload", FinishMediumUpload.self, arguments: ["input": ["uploadId": .variable("uploadId")]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        FinishMediumUploadMutation.Data.self
      ] }

      public var finishMediumUpload: FinishMediumUpload { __data["finishMediumUpload"] }

      /// FinishMediumUpload
      ///
      /// Parent Type: `FinishMediumUploadResult`
      public struct FinishMediumUpload: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.FinishMediumUploadResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsFinishMediumUploadPayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          FinishMediumUploadMutation.Data.FinishMediumUpload.self
        ] }

        public var asFinishMediumUploadPayload: AsFinishMediumUploadPayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// FinishMediumUpload.AsFinishMediumUploadPayload
        ///
        /// Parent Type: `FinishMediumUploadPayload`
        public struct AsFinishMediumUploadPayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = FinishMediumUploadMutation.Data.FinishMediumUpload
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.FinishMediumUploadPayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("medium", Medium.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            FinishMediumUploadMutation.Data.FinishMediumUpload.self,
            FinishMediumUploadMutation.Data.FinishMediumUpload.AsFinishMediumUploadPayload.self
          ] }

          public var medium: Medium { __data["medium"] }

          /// FinishMediumUpload.AsFinishMediumUploadPayload.Medium
          ///
          /// Parent Type: `Medium`
          public struct Medium: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Medium }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("uuid", HackersPub.UUID.self),
              .field("url", HackersPub.URL.self),
              .field("type", HackersPub.MediaType.self),
              .field("width", Int?.self),
              .field("height", Int?.self),
              .field("contentHash", HackersPub.Sha256?.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              FinishMediumUploadMutation.Data.FinishMediumUpload.AsFinishMediumUploadPayload.Medium.self
            ] }

            public var uuid: HackersPub.UUID { __data["uuid"] }
            /// Public URL for the stored medium.
            public var url: HackersPub.URL { __data["url"] }
            /// The medium's media type. Local uploads are stored as WebP.
            public var type: HackersPub.MediaType { __data["type"] }
            public var width: Int? { __data["width"] }
            public var height: Int? { __data["height"] }
            /// SHA-256 hash of the normalized stored content, if known.
            public var contentHash: HackersPub.Sha256? { __data["contentHash"] }
          }
        }

        /// FinishMediumUpload.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = FinishMediumUploadMutation.Data.FinishMediumUpload
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            FinishMediumUploadMutation.Data.FinishMediumUpload.self,
            FinishMediumUploadMutation.Data.FinishMediumUpload.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// FinishMediumUpload.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = FinishMediumUploadMutation.Data.FinishMediumUpload
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            FinishMediumUploadMutation.Data.FinishMediumUpload.self,
            FinishMediumUploadMutation.Data.FinishMediumUpload.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}