// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A stored media object (image). Two-step upload flow: call `startMediumUpload` to get a pre-signed upload URL, PUT the image to that URL, then call `finishMediumUpload` to complete the transaction. Alternatively, call `createMedium` with a remote URL to import an image directly. Unreferenced media older than the grace period are deleted by the `deleteOrphanMedia` mutation.
  static let Medium = ApolloAPI.Object(
    typename: "Medium",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}