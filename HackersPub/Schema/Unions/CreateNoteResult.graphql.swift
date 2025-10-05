// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let CreateNoteResult = Union(
    name: "CreateNoteResult",
    possibleTypes: [
      HackersPub.Objects.CreateNotePayload.self,
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self
    ]
  )
}