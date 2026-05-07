// @generated
// This file was automatically generated and should not be edited.

@_spi(Internal) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct CreateNoteMediumInput: InputObject {
    @_spi(Unsafe) public private(set) var __data: InputDict

    @_spi(Unsafe) public init(_ data: InputDict) {
      __data = data
    }

    public init(
      alt: String,
      mediumId: UUID
    ) {
      __data = InputDict([
        "alt": alt,
        "mediumId": mediumId
      ])
    }

    /// Alternative text for this note's use of the medium.
    public var alt: String {
      get { __data["alt"] }
      set { __data["alt"] = newValue }
    }

    /// UUID of a Medium to attach to the note.
    public var mediumId: UUID {
      get { __data["mediumId"] }
      set { __data["mediumId"] = newValue }
    }
  }

}