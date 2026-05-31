// @generated
// This file was automatically generated and should not be edited.

@_spi(Internal) import ApolloAPI

public extension HackersPub {
  /// Ordering for the `newsStories` feed of shared links.
  enum NewsOrder: String, EnumType {
    /// Highest total weighted engagement mass first, ignoring recency: an all-time-best view rather than what is hot right now.
    case allTime = "ALL_TIME"
    /// Most recently first-shared links first, ignoring engagement.
    case newest = "NEWEST"
    /// Hacker-News-style score combining weighted engagement mass with recency.  The default; what most readers want.
    case popular = "POPULAR"
  }

}