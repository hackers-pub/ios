// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// OpenGraph / oEmbed metadata for a link embedded in a post. Populated asynchronously after the post is created; individual fields may be `null` until the metadata fetch completes or if the linked page does not expose the corresponding tag.  Not resolvable via `node(id:)` when every post referencing the link is censored or authored by a sanction-hidden actor, for this viewer: the linked URL is part of the moderation-hidden content.
  static let PostLink = ApolloAPI.Object(
    typename: "PostLink",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}