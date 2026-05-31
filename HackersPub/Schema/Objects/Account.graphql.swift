// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A local user account on this Hackers' Pub instance. Every `Account` has exactly one `Actor` (its public ActivityPub identity) and holds login credentials, settings, and moderation state. `Account` is only returned for the authenticated viewer and for moderator-only queries; all public identity data (name, bio, posts, followers) lives on `Actor`.
  static let Account = ApolloAPI.Object(
    typename: "Account",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}