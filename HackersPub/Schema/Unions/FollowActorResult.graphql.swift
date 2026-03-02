// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let FollowActorResult = Union(
    name: "FollowActorResult",
    possibleTypes: [
      HackersPub.Objects.FollowActorPayload.self,
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self
    ]
  )
}