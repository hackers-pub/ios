// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let AddNewsExcludedPatternResult = Union(
    name: "AddNewsExcludedPatternResult",
    possibleTypes: [
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NewsExcludedPattern.self,
      HackersPub.Objects.NotAuthenticatedError.self,
      HackersPub.Objects.NotAuthorizedError.self
    ]
  )
}