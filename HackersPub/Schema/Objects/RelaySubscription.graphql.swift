// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A subscription that makes this instance's instance actor follow an ActivityPub relay, so the relay forwards public posts to this instance. Created via `subscribeRelay` and removed via `unsubscribeRelay`. Only moderators can read `RelaySubscription` values; it is purely server (instance) state and is not tied to any user account.
  static let RelaySubscription = ApolloAPI.Object(
    typename: "RelaySubscription",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}