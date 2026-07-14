// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public extension HackersPub.Objects {
  /// A local account on this Hackers' Pub instance. Every `Account` has exactly one `Actor` (its public ActivityPub identity). `PERSONAL` accounts hold login credentials and settings; `ORGANIZATION` accounts are controlled through personal member accounts. `Account` is returned for the authenticated viewer, organization management, and moderator-only queries; public identity data lives on `Actor`.
  static let Account = ApolloAPI.Object(
    typename: "Account",
    implementedInterfaces: [HackersPub.Interfaces.Node.self],
    keyFields: nil
  )
}