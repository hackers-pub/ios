// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A stored media object (image). Two-step upload flow: call `startMediumUpload` to get a pre-signed upload URL, PUT the image to that URL, then call `finishMediumUpload` to complete the transaction. Alternatively, call `createMedium` with a remote URL to import an image directly. Unreferenced media older than the grace period are deleted by the `deleteOrphanMedia` mutation.  Resolvable via `node(id:)` when it has at least one reference visible to the viewer: the avatar of an account that is not banned, or a published post that is neither censored nor authored by a sanction-hidden actor (the viewer's own account/posts and moderators always count as visible). Hidden when it has references but every avatar and post reference is moderation-hidden for the viewer; fresh, orphan, and draft-only media (with no such references) remain resolvable.
  static let Medium = ApolloAPI.Object(
    typename: "Medium",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}