// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// An appeal a sanctioned user filed against a moderation action. Resolvable by the appellant (their own appeal) and by moderators; moderator-only fields (`action`, `appellant`, `reviewer`) carry an additional scope so the appellant cannot reach the case, the other reports, or the moderators through their appeal.
  static let FlagAppeal = ApolloAPI.Object(
    typename: "FlagAppeal",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}