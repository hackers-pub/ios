// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

public extension HackersPub {
  struct MarkNotificationsAsReadMutation: GraphQLMutation {
    public static let operationName: String = "MarkNotificationsAsReadMutation"
    public static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation MarkNotificationsAsReadMutation($upTo: UUID) { markNotificationsAsRead(upTo: $upTo) }"#
      ))

    public var upTo: GraphQLNullable<UUID>

    public init(upTo: GraphQLNullable<UUID>) {
      self.upTo = upTo
    }

    @_spi(Unsafe) public var __variables: Variables? { ["upTo": upTo] }

    public struct Data: HackersPub.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { HackersPub.Objects.Mutation }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("markNotificationsAsRead", HackersPub.DateTime.self, arguments: ["upTo": .variable("upTo")]),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        MarkNotificationsAsReadMutation.Data.self
      ] }

      /// Marks notifications as read up to a notification, or the current time when omitted. Returns the timestamp.
      public var markNotificationsAsRead: HackersPub.DateTime { __data["markNotificationsAsRead"] }
    }
  }

}