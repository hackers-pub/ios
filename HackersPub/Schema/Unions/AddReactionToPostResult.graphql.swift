// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let AddReactionToPostResult = Union(
    name: "AddReactionToPostResult",
    possibleTypes: [
      HackersPub.Objects.AddReactionToPostPayload.self,
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self
    ]
  )
}