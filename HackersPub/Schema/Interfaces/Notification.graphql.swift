// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Interfaces {
  /// A notification for the account holder about social activity related to their posts or profile. Multiple actors can trigger the same notification (e.g., several people reacting to the same post are merged). The `actors` field lists them newest-first.
  static let Notification = ApolloAPI.Interface(
    name: "Notification",
    keyFields: nil,
    implementingObjects: [
      "FollowNotification",
      "MentionNotification",
      "QuoteNotification",
      "QuotedPostUpdatedNotification",
      "ReactNotification",
      "ReplyNotification",
      "ShareNotification",
      "SharedPostUpdatedNotification"
    ]
  )
}