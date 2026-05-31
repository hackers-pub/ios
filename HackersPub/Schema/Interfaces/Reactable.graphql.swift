// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Interfaces {
  /// An object that can receive emoji reactions. Implemented by `Post` types (`Note`, `Article`, `Question`).
  static let Reactable = ApolloAPI.Interface(
    name: "Reactable",
    keyFields: nil,
    implementingObjects: [
      "Article",
      "Note",
      "Question"
    ]
  )
}