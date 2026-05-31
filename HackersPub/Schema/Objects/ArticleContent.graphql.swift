// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A single language version of an `Article`'s content. Each language is stored separately; `Article.contents` lists all available translations. LLM-translated versions have a non-null `translator` and `originalLanguage`.
  static let ArticleContent = ApolloAPI.Object(
    typename: "ArticleContent",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}