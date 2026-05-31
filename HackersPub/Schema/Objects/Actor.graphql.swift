// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// An ActivityPub actor: the public identity used for federation. Actors can be local (originating from this instance, `local: true`) or federated (from another instance, `local: false`). Local actors have an associated `Account` that holds login credentials and settings; remote actors do not. When in doubt, use `Actor` for display and `Account` only for settings that belong to the authenticated viewer.
  static let Actor = ApolloAPI.Object(
    typename: "Actor",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}