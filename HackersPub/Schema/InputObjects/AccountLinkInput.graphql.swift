// @generated
// This file was automatically generated and should not be edited.

@_spi(Internal) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct AccountLinkInput: InputObject {
    @_spi(Unsafe) public private(set) var __data: InputDict

    @_spi(Unsafe) public init(_ data: InputDict) {
      __data = data
    }

    public init(
      name: String,
      url: URL
    ) {
      __data = InputDict([
        "name": name,
        "url": url
      ])
    }

    public var name: String {
      get { __data["name"] }
      set { __data["name"] = newValue }
    }

    public var url: URL {
      get { __data["url"] }
      set { __data["url"] = newValue }
    }
  }

}