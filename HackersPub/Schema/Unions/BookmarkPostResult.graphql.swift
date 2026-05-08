// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let BookmarkPostResult = Union(
    name: "BookmarkPostResult",
    possibleTypes: [
      HackersPub.Objects.BookmarkPostPayload.self,
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self
    ]
  )
}