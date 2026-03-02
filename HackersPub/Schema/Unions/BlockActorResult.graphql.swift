// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let BlockActorResult = Union(
    name: "BlockActorResult",
    possibleTypes: [
      HackersPub.Objects.BlockActorPayload.self,
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self
    ]
  )
}