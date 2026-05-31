// @generated
// This file was automatically generated and should not be edited.

@_spi(Internal) import ApolloAPI

public extension HackersPub {
  /// Discriminant used to filter a connection to a single post type. This enum does not appear on the `Post` interface itself; use __typename` or inline fragments to distinguish concrete types.
  enum PostType: String, EnumType {
    /// Long-form article with a title, year-based slug URL, and optional multi-language translations.
    case article = "ARTICLE"
    /// Short microblog post (equivalent to a Mastodon Status or ActivityPub Note).
    case note = "NOTE"
    /// ActivityPub Question (poll) originating from a federated instance. Creating new Questions locally is not supported.
    case question = "QUESTION"
  }

}