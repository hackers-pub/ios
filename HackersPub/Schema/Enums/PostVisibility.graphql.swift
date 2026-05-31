// @generated
// This file was automatically generated and should not be edited.

@_spi(Internal) import ApolloAPI

public extension HackersPub {
  /// Controls who can see a post and whether it appears in timelines. Visibility is set at creation time and cannot be changed for posts that have already been federated to remote instances.
  enum PostVisibility: String, EnumType {
    /// Visible only to explicitly @-mentioned actors — the closest equivalent to a direct message. Not delivered to followers who were not mentioned.
    case direct = "DIRECT"
    /// Visible only to the actor's approved followers. Never appears in any public timeline. Federated only to follower inboxes.
    case followers = "FOLLOWERS"
    /// Not visible to anyone other than the author. Used internally for soft-deleted or administratively hidden posts; do not set this value when creating posts.
    case none = "NONE"
    /// Visible to everyone including unauthenticated visitors. Appears in the public timeline and the actor's public post list. Federated to all known instances.
    case `public` = "PUBLIC"
    /// Accessible via direct link but excluded from the public timeline. Use for posts that should be reachable without being broadcast widely.
    case unlisted = "UNLISTED"
  }

}