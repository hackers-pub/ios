// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A poll attached to a `Question` post. Contains options, vote counts, and the voting deadline.  When the owning `Question` is censored or its author is hidden by a moderation sanction, the poll (including its option titles) is part of the hidden content and is only resolvable by the author and moderators, even through direct `node(id:)` lookups.
  static let Poll = ApolloAPI.Object(
    typename: "Poll",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}