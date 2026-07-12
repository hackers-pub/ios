import Foundation
import Testing

struct AppIconAccessibilityTests {
    @Test func appIconEntriesUseLocalizedDisplayNameKeysAndRetainSelectionTrait() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("HackersPub/Views/SettingsView.swift"),
            encoding: .utf8
        )

        let appIconsStart = try #require(
            settingsSource.range(of: "private let appIcons: [(name: String, displayNameKey: String)] = [")
        )
        let appIconsTail = settingsSource[appIconsStart.lowerBound...]
        let appIconsEnd = try #require(appIconsTail.range(of: "\n    ]"))
        let appIconEntries = appIconsTail[..<appIconsEnd.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("(\"") }

        #expect(
            appIconEntries == [
                "(\"Logo\", \"settings.appIcon.default\"),",
                "(\"Cry\", \"settings.appIcon.cry\"),",
                "(\"Curious\", \"settings.appIcon.curious\"),",
                "(\"Frown\", \"settings.appIcon.frown\"),",
                "(\"Wink\", \"settings.appIcon.wink\")"
            ]
        )

        let sectionStart = try #require(settingsSource.range(of: "private struct AppIconSettingsSection"))
        let sectionTail = settingsSource[sectionStart.lowerBound...]
        let sectionEnd = try #require(sectionTail.range(of: "\n#endif"))
        let sectionSource = sectionTail[..<sectionEnd.lowerBound]

        #expect(sectionSource.contains("NSLocalizedString(icon.displayNameKey"))
        #expect(
            sectionSource.contains(
                ".accessibilityAddTraits(currentAppIcon == icon.name ? .isSelected : [])"
            )
        )
    }
}
