import Foundation
@testable import HackersPub
import SwiftUI
import Testing

@MainActor
private struct SettingsMarkdownMaxLengthStore {
    @AppStorage var markdownMaxLength: Int

    init(defaults: UserDefaults) {
        _markdownMaxLength = AppStorage(
            wrappedValue: MarkdownMaxLengthPreference.defaultValue,
            MarkdownMaxLengthPreference.key,
            store: defaults
        )
    }
}

@MainActor
private struct PostMarkdownMaxLengthStore {
    @AppStorage var markdownMaxLength: Int

    init(defaults: UserDefaults) {
        _markdownMaxLength = AppStorage(
            wrappedValue: MarkdownMaxLengthPreference.defaultValue,
            MarkdownMaxLengthPreference.key,
            store: defaults
        )
    }
}

@MainActor
struct MarkdownMaxLengthPreferenceTests {
    @Test func appStorageUsesTheSharedDefaultAndPersistsTheUnlimitedValue() throws {
        let suiteName = "MarkdownMaxLengthPreferenceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(MarkdownMaxLengthPreference.defaultValue == 300)
        #expect(MarkdownMaxLengthPreference.unlimitedValue == 0)
        #expect(
            defaults.persistentDomain(forName: suiteName)?[MarkdownMaxLengthPreference.key] == nil
        )

        let settingsStore = SettingsMarkdownMaxLengthStore(defaults: defaults)
        #expect(settingsStore.markdownMaxLength == MarkdownMaxLengthPreference.defaultValue)

        settingsStore.markdownMaxLength = 700
        let postStore = PostMarkdownMaxLengthStore(defaults: defaults)
        #expect(postStore.markdownMaxLength == 700)
        #expect(
            defaults.persistentDomain(forName: suiteName)?[MarkdownMaxLengthPreference.key] as? Int == 700
        )

        settingsStore.markdownMaxLength = MarkdownMaxLengthPreference.unlimitedValue
        let unlimitedPostStore = PostMarkdownMaxLengthStore(defaults: defaults)
        #expect(unlimitedPostStore.markdownMaxLength == MarkdownMaxLengthPreference.unlimitedValue)
        #expect(
            defaults.persistentDomain(forName: suiteName)?[MarkdownMaxLengthPreference.key] as? Int == 0
        )
    }
}
