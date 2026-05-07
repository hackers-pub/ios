// @generated
// This file was automatically generated and should not be edited.

@_spi(Internal) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct UpdateArticleMediumInput: InputObject {
    @_spi(Unsafe) public private(set) var __data: InputDict

    @_spi(Unsafe) public init(_ data: InputDict) {
      __data = data
    }

    public init(
      key: GraphQLNullable<String> = nil,
      mediumId: UUID
    ) {
      __data = InputDict([
        "key": key,
        "mediumId": mediumId
      ])
    }

    /// Key used in article markdown as hp-medium:KEY. Defaults to mediumId.
    public var key: GraphQLNullable<String> {
      get { __data["key"] }
      set { __data["key"] = newValue }
    }

    /// UUID of a Medium to make available to the article source.
    public var mediumId: UUID {
      get { __data["mediumId"] }
      set { __data["mediumId"] = newValue }
    }
  }

}