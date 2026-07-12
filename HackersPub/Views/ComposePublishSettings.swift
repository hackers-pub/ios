@preconcurrency import Apollo
import Foundation

struct ComposeLocaleSelection {
    private(set) var selectedLocale: String
    private(set) var wasManuallySelected = false

    mutating func selectManually(_ locale: String) {
        selectedLocale = locale
        wasManuallySelected = true
    }

    mutating func applyAutomaticDetection(_ locale: String?) {
        guard !wasManuallySelected, let locale, !locale.isEmpty else { return }
        selectedLocale = locale
    }

    func localeToPersist(comparedTo persistedLocale: String) -> String? {
        selectedLocale == persistedLocale ? nil : selectedLocale
    }
}

struct ComposePreparedPublishSettings {
    let content: String
    let language: String
    let visibility: GraphQLEnum<HackersPub.PostVisibility>
    let revision: ComposeSubmissionRevision

    func localeToPersist(
        after result: ComposeNoteSubmissionResult,
        successfulRevision: ComposeSubmissionRevision,
        comparedTo persistedLocale: String
    ) -> String? {
        guard case .success = result, revision == successfulRevision else { return nil }
        return language == persistedLocale ? nil : language
    }
}

struct ComposePublishSettings {
    private var localeSelection: ComposeLocaleSelection
    private(set) var visibility: GraphQLEnum<HackersPub.PostVisibility>

    var language: String {
        localeSelection.selectedLocale
    }

    init(
        language: String,
        visibility: GraphQLEnum<HackersPub.PostVisibility>
    ) {
        localeSelection = ComposeLocaleSelection(selectedLocale: language)
        self.visibility = visibility
    }

    @discardableResult
    mutating func selectLanguage(_ language: String, isBusy: Bool) -> Bool {
        guard !isBusy else { return false }
        localeSelection.selectManually(language)
        return true
    }

    @discardableResult
    mutating func selectVisibility(
        _ visibility: GraphQLEnum<HackersPub.PostVisibility>,
        isBusy: Bool
    ) -> Bool {
        guard !isBusy else { return false }
        self.visibility = visibility
        return true
    }

    mutating func applyAutomaticLanguage(_ language: String?, isBusy: Bool) {
        guard !isBusy else { return }
        localeSelection.applyAutomaticDetection(language)
    }

    func prepared(
        content: String,
        effectiveVisibility: GraphQLEnum<HackersPub.PostVisibility>? = nil,
        revision: ComposeSubmissionRevision
    ) -> ComposePreparedPublishSettings {
        ComposePreparedPublishSettings(
            content: content,
            language: language,
            visibility: effectiveVisibility ?? visibility,
            revision: revision
        )
    }
}
