// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// An individual report filed against an actor or one of their posts. Multiple reports on the same target are grouped into a single case for moderators.  A `Flag` is only resolvable by its reporter (their own report history) and by moderators; the reported user never sees `Flag` values, only the sanitized sanction surface.  Reporter-identifying fields (`reporter`) are additionally restricted to moderators.
  static let Flag = ApolloAPI.Object(
    typename: "Flag",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}