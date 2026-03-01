// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let DeletePostResult = Union(
    name: "DeletePostResult",
    possibleTypes: [
      HackersPub.Objects.DeletePostPayload.self,
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self,
      HackersPub.Objects.SharedPostDeletionNotAllowedError.self
    ]
  )
}