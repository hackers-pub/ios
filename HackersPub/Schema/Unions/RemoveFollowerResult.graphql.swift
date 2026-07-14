// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  /// Result of removing a follower: the updated actors on success, or a typed authentication or input error.
  static let RemoveFollowerResult = Union(
    name: "RemoveFollowerResult",
    possibleTypes: [
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self,
      HackersPub.Objects.OrganizationPermissionError.self,
      HackersPub.Objects.RemoveFollowerPayload.self
    ]
  )
}