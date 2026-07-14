// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// An ActivityPub actor: the public identity used for federation. Actors can be local (originating from this instance, `local: true`) or federated (from another instance, `local: false`). Local actors have an associated `Account`; only `PERSONAL` accounts hold direct login credentials, while `ORGANIZATION` accounts are controlled through memberships. When in doubt, use `Actor` for display and `Account` for viewer, organization, or moderation state.
  static let Actor = ApolloAPI.Object(
    typename: "Actor",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}