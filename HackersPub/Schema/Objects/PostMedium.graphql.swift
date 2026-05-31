// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A media attachment on a post. For local posts this refers to an uploaded `Medium` stored on this instance; for federated posts the `url` points to the remote media URL on the originating instance.
  static let PostMedium = ApolloAPI.Object(
    typename: "PostMedium",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}