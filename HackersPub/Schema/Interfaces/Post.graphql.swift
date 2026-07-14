// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Interfaces {
  /// Abstract base for all content types: `Note` (short microblog posts), `Article` (long-form blog posts), and `Question` (polls from federated instances). Most timeline and feed queries return this interface; use `__typename` or inline fragments to access type-specific fields.  Content-bearing fields are redacted (empty or `null`) when the post is censored or its author is hidden by a moderation sanction (a banned local actor, or a remote actor under an active federation block), unless the viewer is the author or a moderator; list queries exclude such posts entirely, so this matters for direct `node(id:)` lookups and nested relations.
  static let Post = ApolloAPI.Interface(
    name: "Post",
    keyFields: nil,
    implementingObjects: [
      "Article",
      "Note",
      "Question"
    ]
  )
}