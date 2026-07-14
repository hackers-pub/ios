// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// An ActivityPub `Question` poll. Local Questions are source-backed short posts with immutable poll settings; remote Questions may have `null` for `sourceId`. Use `Question.sourceId` for source-backed local Question routes, and fall back to `Post.uuid` for federated remote Questions and local share wrappers.
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