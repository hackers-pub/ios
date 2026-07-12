import Foundation
@testable import HackersPub
import Testing

struct NotificationMessageFormatterTests {
    @Test("SOC-11: English notification variants use complete one, two, and many-actor sentences")
    func englishFormatsAllActorCounts() {
        #expect(
            NotificationMessageFormatter.format(
                actorNames: ["Ada"],
                kind: .followed,
                localized: english
            ).accessibilityText == "Ada followed you"
        )
        #expect(
            NotificationMessageFormatter.format(
                actorNames: ["Ada", "Grace"],
                kind: .reacted,
                localized: english
            ).accessibilityText == "Ada and Grace reacted to your note"
        )
        #expect(
            NotificationMessageFormatter.format(
                actorNames: ["Ada", "Grace", "Linus"],
                kind: .shared,
                localized: english
            ).accessibilityText == "Ada and 2 others shared your note"
        )
    }

    @Test("SOC-11: Korean aggregate sentences do not append an extra honorific after the count")
    func koreanFormatsAllActorCountsWithoutBrokenParticles() {
        let one = NotificationMessageFormatter.format(
            actorNames: ["홍길동"],
            kind: .followed,
            localized: korean
        )
        let two = NotificationMessageFormatter.format(
            actorNames: ["홍길동", "김코덱스"],
            kind: .replied,
            localized: korean
        )
        let many = NotificationMessageFormatter.format(
            actorNames: ["홍길동", "김코덱스", "이테스트"],
            kind: .reacted,
            localized: korean
        )

        #expect(one.accessibilityText == "홍길동님이 팔로우했습니다")
        #expect(two.accessibilityText == "홍길동님과 김코덱스님이 답글을 남겼습니다")
        #expect(many.accessibilityText == "홍길동님 외 2명이 반응했습니다")
        #expect(!many.accessibilityText.contains("명님"))
    }

    @Test("SOC-11: every post and relationship variant chooses a complete localized template")
    func allNotificationKindsUseStructuredTemplates() {
        for kind in NotificationMessageKind.allCases {
            let expected: String
            switch kind {
            case .followed:
                expected = "Ada followed you"
            case .mentioned:
                expected = "Ada mentioned you"
            case .replied:
                expected = "Ada replied to your note"
            case .quoted:
                expected = "Ada quoted your note"
            case .reacted:
                expected = "Ada reacted to your note"
            case .shared:
                expected = "Ada shared your note"
            }
            #expect(
                NotificationMessageFormatter.format(
                    actorNames: ["Ada"],
                    kind: kind,
                    localized: english
                ).accessibilityText == expected
            )
        }
    }

    @Test("SOC-11: malicious remote names are escaped without corrupting VoiceOver in every kind and locale")
    func maliciousNamesAreSafeForHTMLAndCompleteForAccessibility() {
        let maliciousName = #"<b>Ada & &amp; "Grace" 'Linus'</b>"#
        let localizers: [(String) -> String] = [english, korean]

        for localize in localizers {
            for kind in NotificationMessageKind.allCases {
                let message = NotificationMessageFormatter.format(
                    actorNames: [maliciousName],
                    kind: kind,
                    localized: localize
                )
                let key = "notifications.message.\(kind.localizationComponent).one"
                let expectedPlainText = String(format: localize(key), arguments: [maliciousName])

                #expect(!message.html.contains("<b>"))
                #expect(message.html.contains("&lt;b&gt;"))
                #expect(message.html.contains("&amp;amp;"))
                #expect(message.html.contains("&quot;Grace&quot;"))
                #expect(message.html.contains("&#39;Linus&#39;"))
                #expect(message.accessibilityText == expectedPlainText)
            }
        }
    }

    @Test("SOC-11: both locale files contain all structured notification message keys")
    func localeFilesContainEveryStructuredNotificationMessageKey() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let expectedKeys = Set(NotificationMessageKind.allCases.flatMap { kind in
            NotificationMessageActorCount.allCases.map { count in
                "notifications.message.\(kind.localizationComponent).\(count.localizationComponent)"
            }
        } + ["notifications.actor.unknown"])

        for locale in ["en", "ko"] {
            let strings = try String(
                contentsOf: root.appending(path: "HackersPub/\(locale).lproj/Localizable.strings"),
                encoding: .utf8
            )
            let keys = Set(strings.matches(of: /"([^"]+)"\s*=/).map { String($0.1) })
            #expect(expectedKeys.isSubset(of: keys))
        }
    }

    private func english(_ key: String) -> String {
        localized(key, in: englishTemplates)
    }

    private func korean(_ key: String) -> String {
        localized(key, in: koreanTemplates)
    }

    private func localized(_ key: String, in templates: String) -> String {
        templates
            .split(separator: "\n")
            .compactMap { line -> (String, String)? in
                let fields = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard fields.count == 2 else { return nil }
                return (fields[0], fields[1])
            }
            .first(where: { $0.0 == key })?
            .1 ?? key
    }

    private var englishTemplates: String {
        """
        notifications.actor.unknown=Someone
        notifications.message.followed.one=%1$@ followed you
        notifications.message.followed.two=%1$@ and %2$@ followed you
        notifications.message.followed.many=%1$@ and %2$d others followed you
        notifications.message.mentioned.one=%1$@ mentioned you
        notifications.message.mentioned.two=%1$@ and %2$@ mentioned you
        notifications.message.mentioned.many=%1$@ and %2$d others mentioned you
        notifications.message.replied.one=%1$@ replied to your note
        notifications.message.replied.two=%1$@ and %2$@ replied to your note
        notifications.message.replied.many=%1$@ and %2$d others replied to your note
        notifications.message.quoted.one=%1$@ quoted your note
        notifications.message.quoted.two=%1$@ and %2$@ quoted your note
        notifications.message.quoted.many=%1$@ and %2$d others quoted your note
        notifications.message.reacted.one=%1$@ reacted to your note
        notifications.message.reacted.two=%1$@ and %2$@ reacted to your note
        notifications.message.reacted.many=%1$@ and %2$d others reacted to your note
        notifications.message.shared.one=%1$@ shared your note
        notifications.message.shared.two=%1$@ and %2$@ shared your note
        notifications.message.shared.many=%1$@ and %2$d others shared your note
        """
    }

    private var koreanTemplates: String {
        """
        notifications.actor.unknown=누군가
        notifications.message.followed.one=%1$@님이 팔로우했습니다
        notifications.message.followed.two=%1$@님과 %2$@님이 팔로우했습니다
        notifications.message.followed.many=%1$@님 외 %2$d명이 팔로우했습니다
        notifications.message.mentioned.one=%1$@님이 언급했습니다
        notifications.message.mentioned.two=%1$@님과 %2$@님이 언급했습니다
        notifications.message.mentioned.many=%1$@님 외 %2$d명이 언급했습니다
        notifications.message.replied.one=%1$@님이 답글을 남겼습니다
        notifications.message.replied.two=%1$@님과 %2$@님이 답글을 남겼습니다
        notifications.message.replied.many=%1$@님 외 %2$d명이 답글을 남겼습니다
        notifications.message.quoted.one=%1$@님이 인용했습니다
        notifications.message.quoted.two=%1$@님과 %2$@님이 인용했습니다
        notifications.message.quoted.many=%1$@님 외 %2$d명이 인용했습니다
        notifications.message.reacted.one=%1$@님이 반응했습니다
        notifications.message.reacted.two=%1$@님과 %2$@님이 반응했습니다
        notifications.message.reacted.many=%1$@님 외 %2$d명이 반응했습니다
        notifications.message.shared.one=%1$@님이 공유했습니다
        notifications.message.shared.two=%1$@님과 %2$@님이 공유했습니다
        notifications.message.shared.many=%1$@님 외 %2$d명이 공유했습니다
        """
    }
}
