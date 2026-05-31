// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A long-form blog article written on this platform. Articles have a title, year-based URL slug, and can have multiple `ArticleContent` translations. Remote articles federated from other instances lack a local `articleSource` and will have `null` for `slug`, `publishedYear`, and `tags`.
  static let Article = ApolloAPI.Object(
    typename: "Article",
    implementedInterfaces: [
      HackersPub.Interfaces.Node.self,
      HackersPub.Interfaces.Post.self,
      HackersPub.Interfaces.Reactable.self
    ],
    keyFields: nil
  )
}