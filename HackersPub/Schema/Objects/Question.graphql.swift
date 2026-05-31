// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// An ActivityPub Question (poll) originating from a federated instance. Hackers' Pub does not support creating `Question`s locally; local users can vote on and boost remote questions only. Always use `Post.uuid` (the row PK) for internal permalinks; there is no local `sourceId`.
  static let Question = ApolloAPI.Object(
    typename: "Question",
    implementedInterfaces: [
      HackersPub.Interfaces.Node.self,
      HackersPub.Interfaces.Post.self,
      HackersPub.Interfaces.Reactable.self
    ],
    keyFields: nil
  )
}