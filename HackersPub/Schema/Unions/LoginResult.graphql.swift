// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  static let LoginResult = Union(
    name: "LoginResult",
    possibleTypes: [
      HackersPub.Objects.AccountNotFoundError.self,
      HackersPub.Objects.LoginChallenge.self
    ]
  )
}