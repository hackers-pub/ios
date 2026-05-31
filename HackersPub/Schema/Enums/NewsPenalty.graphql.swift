// @generated
// This file was automatically generated and should not be edited.

@_spi(Internal) import ApolloAPI

public extension HackersPub {
  /// A moderator's score penalty on a news link, demoting it in the `POPULAR` feed.  Set via `setNewsScorePenalty`; only moderators can read or change it.  To remove a link from every order instead, exclude its URL with a pattern (`addNewsExcludedPattern`).
  enum NewsPenalty: String, EnumType {
    /// Sink the link to the bottom of the popular feed.
    case bury = "BURY"
    /// Push the link well down the popular feed.
    case demote = "DEMOTE"
    /// No penalty.
    case none = "NONE"
  }

}