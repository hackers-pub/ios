// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A short-form microblog post, equivalent to a Mastodon Status or ActivityPub Note. Notes can be composed locally or federated in from remote instances. Boost wrappers (`sharedPost` is non-null) have empty content and copy the shared post's URL.
  static let Note = ApolloAPI.Object(
    typename: "Note",
    implementedInterfaces: [
      HackersPub.Interfaces.Node.self,
      HackersPub.Interfaces.Post.self,
      HackersPub.Interfaces.Reactable.self
    ],
    keyFields: nil
  )
}