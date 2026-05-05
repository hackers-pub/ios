// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let DeleteArticleDraftResult = Union(
    name: "DeleteArticleDraftResult",
    possibleTypes: [
      HackersPub.Objects.DeleteArticleDraftPayload.self,
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self
    ]
  )
}