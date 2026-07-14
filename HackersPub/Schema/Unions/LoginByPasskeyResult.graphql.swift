// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  /// The result of `loginByPasskey`: a `Session` on success, or `AccountBannedError` when the passkey is valid but the account is permanently suspended (banned). The field itself is `null` when passkey verification failed.
  static let LoginByPasskeyResult = Union(
    name: "LoginByPasskeyResult",
    possibleTypes: [
      HackersPub.Objects.AccountBannedError.self,
      HackersPub.Objects.Session.self
    ]
  )
}