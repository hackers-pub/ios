// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct CreateNoteMutation: GraphQLMutation {
    public static let operationName: String = "CreateNoteMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation CreateNoteMutation($content: Markdown!, $language: Locale!, $visibility: PostVisibility!, $replyTargetId: ID) { createNote( input: { content: $content language: $language visibility: $visibility replyTargetId: $replyTargetId } ) { __typename ... on CreateNotePayload { note { __typename id content published } } ... on InvalidInputError { inputPath } ... on NotAuthenticatedError { notAuthenticated } } }"#
      ))

    public var content: Markdown
    public var language: Locale
    public var visibility: GraphQLEnum<PostVisibility>
    public var replyTargetId: GraphQLNullable<ID>

    public init(
      content: Markdown,
      language: Locale,
      visibility: GraphQLEnum<PostVisibility>,
      replyTargetId: GraphQLNullable<ID>
    ) {
      self.content = content
      self.language = language
      self.visibility = visibility
      self.replyTargetId = replyTargetId
    }

    @_spi(Unsafe) public var __variables: Variables? { [
      "content": content,
      "language": language,
      "visibility": visibility,
      "replyTargetId": replyTargetId
    ] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("createNote", CreateNote.self, arguments: ["input": [
          "content": .variable("content"),
          "language": .variable("language"),
          "visibility": .variable("visibility"),
          "replyTargetId": .variable("replyTargetId")
        ]]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        CreateNoteMutation.Data.self
      ] }

      public var createNote: CreateNote { __data["createNote"] }

      /// CreateNote
      ///
      /// Parent Type: `CreateNoteResult`
      public struct CreateNote: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Unions.CreateNoteResult }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .inlineFragment(AsCreateNotePayload.self),
          .inlineFragment(AsInvalidInputError.self),
          .inlineFragment(AsNotAuthenticatedError.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          CreateNoteMutation.Data.CreateNote.self
        ] }

        public var asCreateNotePayload: AsCreateNotePayload? { _asInlineFragment() }
        public var asInvalidInputError: AsInvalidInputError? { _asInlineFragment() }
        public var asNotAuthenticatedError: AsNotAuthenticatedError? { _asInlineFragment() }

        /// CreateNote.AsCreateNotePayload
        ///
        /// Parent Type: `CreateNotePayload`
        public struct AsCreateNotePayload: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = CreateNoteMutation.Data.CreateNote
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.CreateNotePayload }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("note", Note.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            CreateNoteMutation.Data.CreateNote.self,
            CreateNoteMutation.Data.CreateNote.AsCreateNotePayload.self
          ] }

          public var note: Note { __data["note"] }

          /// CreateNote.AsCreateNotePayload.Note
          ///
          /// Parent Type: `Note`
          public struct Note: HackersPub.SelectionSet {
            @_spi(Unsafe) public let __data: DataDict
            @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

            @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Note }
            @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
              .field("__typename", String.self),
              .field("id", HackersPub.ID.self),
              .field("content", HackersPub.HTML.self),
              .field("published", HackersPub.DateTime.self),
            ] }
            @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
              CreateNoteMutation.Data.CreateNote.AsCreateNotePayload.Note.self
            ] }

            public var id: HackersPub.ID { __data["id"] }
            public var content: HackersPub.HTML { __data["content"] }
            public var published: HackersPub.DateTime { __data["published"] }
          }
        }

        /// CreateNote.AsInvalidInputError
        ///
        /// Parent Type: `InvalidInputError`
        public struct AsInvalidInputError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = CreateNoteMutation.Data.CreateNote
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.InvalidInputError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("inputPath", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            CreateNoteMutation.Data.CreateNote.self,
            CreateNoteMutation.Data.CreateNote.AsInvalidInputError.self
          ] }

          public var inputPath: String { __data["inputPath"] }
        }

        /// CreateNote.AsNotAuthenticatedError
        ///
        /// Parent Type: `NotAuthenticatedError`
        public struct AsNotAuthenticatedError: HackersPub.InlineFragment {
          @_spi(Unsafe) public let __data: DataDict
          @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

          public typealias RootEntityType = CreateNoteMutation.Data.CreateNote
          @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.NotAuthenticatedError }
          @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
            .field("notAuthenticated", String.self),
          ] }
          @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
            CreateNoteMutation.Data.CreateNote.self,
            CreateNoteMutation.Data.CreateNote.AsNotAuthenticatedError.self
          ] }

          public var notAuthenticated: String { __data["notAuthenticated"] }
        }
      }
    }
  }

}