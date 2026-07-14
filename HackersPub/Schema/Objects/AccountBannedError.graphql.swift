// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// Returned by `completeLoginChallenge` and `loginByPasskey` when the credential is valid but the account is permanently suspended (banned). It is deliberately distinct from a `null` result (which means the credential itself was wrong) so the client can show a ban-specific message rather than a generic failure. Temporary suspension only restricts writing, not signing in, so it never produces this error.
  static let AccountBannedError = ApolloAPI.Object(
    typename: "AccountBannedError",
    implementedInterfaces: [],
    keyFields: nil
  )
}