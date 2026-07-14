// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// Returned by write mutations (posting, reacting, sharing, following, voting) when the authenticated account is under an active moderation suspension.  Suspension only restricts writing; reading still works. Check `suspendedUntil` to tell a temporary suspension (a timestamp) from a permanent one (`null`).
  static let ActorSuspendedError = ApolloAPI.Object(
    typename: "ActorSuspendedError",
    implementedInterfaces: [],
    keyFields: nil
  )
}