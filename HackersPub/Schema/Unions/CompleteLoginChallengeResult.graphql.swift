// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Unions {
  /// The result of `completeLoginChallenge`: a `Session` on success, or `AccountBannedError` when the credential is valid but the account is permanently suspended (banned). The field itself is `null` when the token does not exist or the code does not match.
  static let CompleteLoginChallengeResult = Union(
    name: "CompleteLoginChallengeResult",
    possibleTypes: [
      HackersPub.Objects.AccountBannedError.self,
      HackersPub.Objects.Session.self
    ]
  )
}