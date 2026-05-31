// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// How a link's public shares break down by origin.  Hackers' Pub posts carry the most weight, generic remote instances less, and Bluesky-bridged accounts (`@…@bsky.brid.gy`) the least.  Shares authored by bot accounts (`Service`/`Application` actors) are excluded throughout.
  static let NewsSourceBreakdown = ApolloAPI.Object(
    typename: "NewsSourceBreakdown",
    implementedInterfaces: [],
    keyFields: nil
  )
}