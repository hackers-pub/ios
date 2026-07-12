import Foundation

enum NotificationMessageKind: CaseIterable, Hashable {
    case followed
    case mentioned
    case replied
    case quoted
    case reacted
    case shared

    var localizationComponent: String {
        switch self {
        case .followed:
            "followed"
        case .mentioned:
            "mentioned"
        case .replied:
            "replied"
        case .quoted:
            "quoted"
        case .reacted:
            "reacted"
        case .shared:
            "shared"
        }
    }
}

enum NotificationMessageActorCount: CaseIterable {
    case one
    case two
    case many

    var localizationComponent: String {
        switch self {
        case .one:
            "one"
        case .two:
            "two"
        case .many:
            "many"
        }
    }
}

struct NotificationFormattedMessage: Equatable {
    let html: String
    let accessibilityText: String
}

enum NotificationMessageFormatter {
    static func format(
        actorNames: [String],
        kind: NotificationMessageKind,
        localized: ((String) -> String)? = nil
    ) -> NotificationFormattedMessage {
        let localize = localized ?? { key in
            NSLocalizedString(key, comment: "Notification message format")
        }
        let names = actorNames.filter { !$0.isEmpty }
        let firstName = names.first ?? localize("notifications.actor.unknown")
        let plainNames = names.isEmpty ? [firstName] : names
        let htmlNames = plainNames.map(escapeHTML)
        let actorCount = actorCount(for: names)
        let key = "notifications.message.\(kind.localizationComponent).\(actorCount.localizationComponent)"
        let template = localize(key)

        return NotificationFormattedMessage(
            html: render(template: template, names: htmlNames, actorCount: actorCount),
            accessibilityText: render(template: template, names: plainNames, actorCount: actorCount)
        )
    }

    private static func render(
        template: String,
        names: [String],
        actorCount: NotificationMessageActorCount
    ) -> String {
        switch actorCount {
        case .one:
            String(format: template, locale: .current, arguments: [names[0]])
        case .two:
            String(format: template, locale: .current, arguments: [names[0], names[1]])
        case .many:
            String(format: template, locale: .current, arguments: [names[0], names.count - 1])
        }
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func actorCount(for names: [String]) -> NotificationMessageActorCount {
        switch names.count {
        case 0, 1:
            .one
        case 2:
            .two
        default:
            .many
        }
    }
}
