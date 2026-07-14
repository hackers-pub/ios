// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// An immutable audit record of a moderator decision on a case.  If a decision changes (e.g. through an appeal), a new action is recorded rather than editing this one.  Moderator-only: the reported user sees the sanitized sanction surface instead, which never names the acting moderator; a reported moderator likewise cannot access actions on their own case through this type.
  static let FlagAction = ApolloAPI.Object(
    typename: "FlagAction",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}