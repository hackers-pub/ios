// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct NotificationUnreadCountQuery: GraphQLQuery {
    public static let operationName: String = "NotificationUnreadCountQuery"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"query NotificationUnreadCountQuery { viewer { __typename id unreadNotificationsCount } }"#
      ))

    public init() {}

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Query }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("viewer", Viewer?.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        NotificationUnreadCountQuery.Data.self
      ] }

      /// The `Account` of the currently authenticated user, or `null` when not authenticated. Use this as the entry point for all viewer-specific data (notifications, drafts, settings).
      public var viewer: Viewer? { __data["viewer"] }

      /// Viewer
      ///
      /// Parent Type: `Account`
      public struct Viewer: HackersPub.SelectionSet {
        @_spi(Unsafe) public let __data: DataDict
        @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

        @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Account }
        @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", HackersPub.ID.self),
          .field("unreadNotificationsCount", Int.self),
        ] }
        @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
          NotificationUnreadCountQuery.Data.Viewer.self
        ] }

        public var id: HackersPub.ID { __data["id"] }
        /// Number of notifications created after the account's last `markNotificationsAsRead` call. Only visible to the account holder.
        public var unreadNotificationsCount: Int { __data["unreadNotificationsCount"] }
      }
    }
  }

}