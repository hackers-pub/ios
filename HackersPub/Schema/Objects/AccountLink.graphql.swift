// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A profile link on a local account's public page.  Not resolvable via `node(id:)` when the owning account is permanently suspended (banned) and the viewer is neither the account holder nor a moderator.
  static let AccountLink = ApolloAPI.Object(
    typename: "AccountLink",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}