// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let SharePostResult = Union(
    name: "SharePostResult",
    possibleTypes: [
      HackersPub.Objects.ActorSuspendedError.self,
      HackersPub.Objects.InvalidInputError.self,
      HackersPub.Objects.NotAuthenticatedError.self,
      HackersPub.Objects.OrganizationPermissionError.self,
      HackersPub.Objects.SharePostPayload.self
    ]
  )
}