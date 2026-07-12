import Foundation

/// Read-only post data for lightweight surfaces such as notifications.
///
/// This deliberately excludes viewer state and every mutation capability. A
/// notification payload must be converted to this value before rendering, so it
/// cannot be passed to `PostView` or its interaction controls.
protocol PostPreviewProtocol {
    var route: NotificationPostPreviewRoute? { get }
    var author: PostPreviewAuthor? { get }
    var title: String? { get }
    var published: String? { get }
    var content: String? { get }
    var summary: String? { get }
    var media: [PostPreviewMedia] { get }
}

/// The intentionally narrow projection supplied by the five notification GraphQL
/// post selections. It has no viewer flags, reactions, bookmarks, or mutations.
protocol NotificationPostPreviewSource {
    var notificationPostPreviewFields: NotificationPostPreviewFields { get }
}

struct NotificationPostPreviewFields: Equatable {
    let postID: String?
    let author: PostPreviewAuthor?
    let title: String?
    let published: String?
    let content: String?
    let summary: String?
    let media: [PostPreviewMedia]
}

struct NotificationPostPreviewRoute: Equatable {
    let postID: String

    init?(postID: String?) {
        guard let postID = nonemptyPreviewText(postID),
              !postID.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            return nil
        }

        self.postID = postID
    }
}

struct PostPreviewAuthor: Equatable {
    let name: String?
    let handle: String?
    let avatarURL: URL?

    init(name: String?, handle: String?, avatarURL: String?) {
        self.name = name
        self.handle = handle
        self.avatarURL = previewImageURL(from: avatarURL)
    }
}

struct PostPreviewMedia: Equatable {
    let url: URL?
    let thumbnailURL: URL?
    let alt: String?

    init(url: String?, thumbnailURL: String?, alt: String?) {
        self.url = previewImageURL(from: url)
        self.thumbnailURL = previewImageURL(from: thumbnailURL)
        self.alt = alt
    }

    var displayURL: URL? {
        thumbnailURL ?? url
    }
}

struct NotificationPostPreview: PostPreviewProtocol, Equatable {
    let route: NotificationPostPreviewRoute?
    let author: PostPreviewAuthor?
    let title: String?
    let published: String?
    let content: String?
    let summary: String?
    let media: [PostPreviewMedia]

    init(
        postID: String?,
        author: PostPreviewAuthor?,
        title: String?,
        published: String?,
        content: String?,
        summary: String?,
        media: [PostPreviewMedia]
    ) {
        route = NotificationPostPreviewRoute(postID: postID)
        self.author = author
        self.title = title
        self.published = published
        self.content = content
        self.summary = summary
        self.media = media
    }

    init<Source: NotificationPostPreviewSource>(_ source: Source) {
        let fields = source.notificationPostPreviewFields
        self.init(
            postID: fields.postID,
            author: fields.author,
            title: fields.title,
            published: fields.published,
            content: fields.content,
            summary: fields.summary,
            media: fields.media
        )
    }
}

/// The only interaction a notification preview may expose. It intentionally has
/// no reaction, bookmark, share, edit, or delete case.
enum NotificationPostPreviewAction: Equatable {
    case openDetail(postID: String)
}

struct NotificationPostPreviewPresentation: Equatable {
    let authorName: String?
    let authorHandle: String?
    let authorAvatarURL: URL?
    let title: String?
    let body: String?
    let published: String?
    let thumbnailURL: URL?
    let thumbnailAlt: String?
    let action: NotificationPostPreviewAction?

    init(preview: any PostPreviewProtocol) {
        let authorName = preview.author?.name.flatMap(previewPlainText)
        let authorHandle = preview.author?.handle.flatMap(nonemptyPreviewText)

        if let authorName {
            self.authorName = authorName
            self.authorHandle = authorHandle == authorName ? nil : authorHandle
            authorAvatarURL = preview.author?.avatarURL
        } else {
            self.authorName = authorHandle
            self.authorHandle = nil
            authorAvatarURL = authorHandle == nil ? nil : preview.author?.avatarURL
        }

        title = preview.title.flatMap(previewPlainText)
        body = preview.summary.flatMap(previewPlainText) ?? preview.content.flatMap(previewPlainText)
        published = nonemptyPreviewText(preview.published)

        let thumbnail = preview.media.first { $0.displayURL != nil }
        thumbnailURL = thumbnail?.displayURL
        thumbnailAlt = thumbnail?.alt.flatMap(previewPlainText)
        action = preview.route.map { .openDetail(postID: $0.postID) }
    }

    var accessibilityLabel: String {
        [authorName, title, body, thumbnailAlt, published]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

func previewPlainText(_ html: String) -> String? {
    var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "&nbsp;", with: " ")
    text = text.replacingOccurrences(of: "&amp;", with: "&")
    text = text.replacingOccurrences(of: "&lt;", with: "<")
    text = text.replacingOccurrences(of: "&gt;", with: ">")
    text = text.replacingOccurrences(of: "&quot;", with: "\"")
    text = text.replacingOccurrences(of: "&#39;", with: "'")
    text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return nonemptyPreviewText(text)
}

func nonemptyPreviewText(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func previewImageURL(from value: String?) -> URL? {
    guard let value = nonemptyPreviewText(value),
          let url = URL(string: value),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme),
          url.host != nil
    else {
        return nil
    }

    return url
}
