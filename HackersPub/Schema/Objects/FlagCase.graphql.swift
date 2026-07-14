// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A moderation case: all reports against the same target (an actor, or one of their posts) grouped into a single unit of moderator work.  Cases are created automatically by the first report and joined by subsequent ones while open.  Moderator-only; a reported moderator cannot access their own case (reporter anonymity would be broken otherwise).
  static let FlagCase = ApolloAPI.Object(
    typename: "FlagCase",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}