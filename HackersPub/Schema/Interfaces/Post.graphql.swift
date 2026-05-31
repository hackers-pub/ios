// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Interfaces {
  /// Abstract base for all content types: `Note` (short microblog posts), `Article` (long-form blog posts), and `Question` (polls from federated instances). Most timeline and feed queries return this interface; use `__typename` or inline fragments to access type-specific fields.
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