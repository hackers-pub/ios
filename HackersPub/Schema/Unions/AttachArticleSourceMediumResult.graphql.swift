// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let AttachArticleSourceMediumResult = Union(
    name: "AttachArticleSourceMediumResult",
    possibleTypes: [
      HackersPub.Objects.AttachArticleSourceMediumPayload.self,
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self,
      HackersPub.Objects.NotAuthorizedError.self
    ]
  )
}