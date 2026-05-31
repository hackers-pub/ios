// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// Notification that one or more actors reacted with an emoji to one of this account's posts. The `emoji` and `customEmoji` fields identify which reaction triggered the notification.
  static let ReactNotification = ApolloAPI.Object(
    typename: "ReactNotification",
    implementedInterfaces: [
      HackersPub.Interfaces.Node.self,
      HackersPub.Interfaces.Notification.self
    ],
    keyFields: nil
  )
}