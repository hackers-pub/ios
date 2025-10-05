// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public protocol HackersPub_SelectionSet: ApolloAPI.SelectionSet & ApolloAPI.RootSelectionSet
where Schema == HackersPub.SchemaMetadata {}

public protocol HackersPub_InlineFragment: ApolloAPI.SelectionSet & ApolloAPI.InlineFragment
where Schema == HackersPub.SchemaMetadata {}

public protocol HackersPub_MutableSelectionSet: ApolloAPI.MutableRootSelectionSet
where Schema == HackersPub.SchemaMetadata {}

public protocol HackersPub_MutableInlineFragment: ApolloAPI.MutableSelectionSet & ApolloAPI.InlineFragment
where Schema == HackersPub.SchemaMetadata {}

public extension HackersPub {
  typealias SelectionSet = HackersPub_SelectionSet

  typealias InlineFragment = HackersPub_InlineFragment

  typealias MutableSelectionSet = HackersPub_MutableSelectionSet

  typealias MutableInlineFragment = HackersPub_MutableInlineFragment

  enum SchemaMetadata: ApolloAPI.SchemaMetadata {
    public static let configuration: any ApolloAPI.SchemaConfiguration.Type = SchemaConfiguration.self

    @_spi(Execution) public static func objectType(forTypename typename: String) -> ApolloAPI.Object? {
      switch typename {
      case "Account": return HackersPub.Objects.Account
      case "AccountLink": return HackersPub.Objects.AccountLink
      case "AccountNotFoundError": return HackersPub.Objects.AccountNotFoundError
      case "Actor": return HackersPub.Objects.Actor
      case "ActorPostsConnection": return HackersPub.Objects.ActorPostsConnection
      case "ActorPostsConnectionEdge": return HackersPub.Objects.ActorPostsConnectionEdge
      case "Article": return HackersPub.Objects.Article
      case "ArticleContent": return HackersPub.Objects.ArticleContent
      case "CreateNotePayload": return HackersPub.Objects.CreateNotePayload
      case "CustomEmoji": return HackersPub.Objects.CustomEmoji
      case "FollowNotification": return HackersPub.Objects.FollowNotification
      case "Instance": return HackersPub.Objects.Instance
      case "InvalidInputError": return HackersPub.Objects.InvalidInputError
      case "LoginChallenge": return HackersPub.Objects.LoginChallenge
      case "MentionNotification": return HackersPub.Objects.MentionNotification
      case "Mutation": return HackersPub.Objects.Mutation
      case "NotAuthenticatedError": return HackersPub.Objects.NotAuthenticatedError
      case "Note": return HackersPub.Objects.Note
      case "PageInfo": return HackersPub.Objects.PageInfo
      case "Passkey": return HackersPub.Objects.Passkey
      case "Poll": return HackersPub.Objects.Poll
      case "PostLink": return HackersPub.Objects.PostLink
      case "PostMedium": return HackersPub.Objects.PostMedium
      case "Query": return HackersPub.Objects.Query
      case "QueryPersonalTimelineConnection": return HackersPub.Objects.QueryPersonalTimelineConnection
      case "QueryPersonalTimelineConnectionEdge": return HackersPub.Objects.QueryPersonalTimelineConnectionEdge
      case "QueryPublicTimelineConnection": return HackersPub.Objects.QueryPublicTimelineConnection
      case "QueryPublicTimelineConnectionEdge": return HackersPub.Objects.QueryPublicTimelineConnectionEdge
      case "QuerySearchPostConnection": return HackersPub.Objects.QuerySearchPostConnection
      case "QuerySearchPostConnectionEdge": return HackersPub.Objects.QuerySearchPostConnectionEdge
      case "Question": return HackersPub.Objects.Question
      case "QuoteNotification": return HackersPub.Objects.QuoteNotification
      case "ReactNotification": return HackersPub.Objects.ReactNotification
      case "ReplyNotification": return HackersPub.Objects.ReplyNotification
      case "Session": return HackersPub.Objects.Session
      case "ShareNotification": return HackersPub.Objects.ShareNotification
      default: return nil
      }
    }
  }

  enum Objects {}
  enum Interfaces {}
  enum Unions {}

}