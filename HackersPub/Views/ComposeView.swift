@preconcurrency import Apollo
import Markdown
import NaturalLanguage
import OSLog
import PhotosUI
import SwiftUI
import UIKit

private enum ReplyContextLoadError: LocalizedError {
    case missingPost, missingCursor, inconsistentPost, unsupportedVisibility, paginationLimitExceeded
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case let .requestFailed(message):
            return message
        case .missingPost, .missingCursor, .inconsistentPost, .unsupportedVisibility, .paginationLimitExceeded:
            return NSLocalizedString("compose.reply.contextUnavailable", comment: "Reply context unavailable")
        }
    }
}

let replyContextPaginationLimits = (maximumPageCount: 4, maximumMentionCount: 100)

@MainActor
// swiftlint:disable:next cyclomatic_complexity function_body_length
func loadReplyContext(
    postID: String,
    currentViewerHandle: String?,
    isCurrent: () -> Bool,
    fetchPage: (String?) async throws -> ReplyContextPage
) async -> ReplyContextLoadOutcome {
    var cursor: String?
    var visitedCursors = Set<String>()
    var firstPage: ReplyContextPage?
    var mentionedHandles: [String] = []
    let paginationLimitFailure = ReplyContextLoadError.paginationLimitExceeded.localizedDescription

    while true {
        guard !Task.isCancelled, isCurrent() else { return .ignored }

        let page: ReplyContextPage
        do {
            page = try await fetchPage(cursor)
        } catch {
            return !Task.isCancelled && isCurrent()
                ? .failed(error.localizedDescription)
                : .ignored
        }

        guard !Task.isCancelled, isCurrent() else { return .ignored }
        guard page.postID == postID else {
            return .failed(ReplyContextLoadError.inconsistentPost.localizedDescription)
        }
        guard isSupportedCreateNoteVisibility(page.visibility) else {
            return .failed(ReplyContextLoadError.unsupportedVisibility.localizedDescription)
        }

        if let firstPage {
            guard page.visibility == firstPage.visibility,
                  normalizedMentionHandle(page.authorHandle) == normalizedMentionHandle(firstPage.authorHandle)
            else {
                return .failed(ReplyContextLoadError.inconsistentPost.localizedDescription)
            }
        } else {
            firstPage = page
        }

        let loadedPageCount = visitedCursors.count + 1
        let totalMentionCount = mentionedHandles.count + page.mentionHandles.count
        guard totalMentionCount <= replyContextPaginationLimits.maximumMentionCount else {
            return .failed(paginationLimitFailure)
        }
        mentionedHandles.append(contentsOf: page.mentionHandles)
        guard page.hasNextPage else { break }
        guard let nextCursor = page.endCursor,
              !nextCursor.isEmpty,
              visitedCursors.insert(nextCursor).inserted
        else {
            return .failed(ReplyContextLoadError.missingCursor.localizedDescription)
        }
        guard loadedPageCount < replyContextPaginationLimits.maximumPageCount else {
            return .failed(paginationLimitFailure)
        }
        cursor = nextCursor
    }

    guard let firstPage else {
        return .failed(ReplyContextLoadError.inconsistentPost.localizedDescription)
    }

    return .loaded(
        ReplyContext(
            postID: postID,
            visibility: firstPage.visibility,
            authorHandle: firstPage.authorHandle,
            mentionHandles: orderedMentionHandles(
                authorHandle: firstPage.authorHandle,
                mentionedHandles: mentionedHandles,
                excludingHandle: currentViewerHandle
            )
        )
    )
}

private let composeLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "pub.hackers.HackersPub",
    category: "compose"
)

struct ComposeView: View {
    private struct PhotoAttachmentEditorTarget: Identifiable {
        let id: PendingPhotoAttachment.ID
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @ObservedObject private var fontSettings = FontSettingsManager.shared
    @State private var content: String
    @State private var selectedTextRange = NSRange(location: 0, length: 0)
    @State private var selectedTextCaretRect: CGRect = .zero
    @State private var publishSettings: ComposePublishSettings
    @StateObject private var submissionCoordinator = ComposeSubmissionCoordinator()
    @State private var presentationCoordinator = ComposePresentationCoordinator()
    @State private var showPreview = false
    @State private var isLoadingPreview = false
    @State private var quotedPostPreview: HackersPub.PostDetailQuery.Data.Node.AsPost?
    @State private var isLoadingQuotedPost = false
    @State private var didFailToLoadQuotedPost = false
    @State private var activeMention: ComposeMentionMatch?
    @State private var mentionSuggestions: [HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle] = []
    @State private var isLoadingMentionSuggestions = false
    @State private var mentionSearchTask: Task<Void, Never>?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingPhotoAttachments: [PendingPhotoAttachment] = []
    @State private var editingPhotoAttachment: PhotoAttachmentEditorTarget?
    @State private var dirtyState: ComposeDirtyState
    @State private var replyContext: ReplyContext?
    @State private var isLoadingReplyContext = true
    @State private var replyContextErrorMessage: String?
    @State private var replyContextRequestID = UUID()
    @AppStorage("lastSelectedLocale")
    private var lastSelectedLocale: String = Locale.current.language.languageCode?.identifier ?? "en"

    private var htmlContent: String {
        let document = Document(parsing: content)
        let rawHTML = HTMLFormatter.format(document)
        return HTMLStyles.wrapHTML(rawHTML, css: HTMLStyles.composePreviewCSS)
    }

    private var isBusy: Bool {
        submissionCoordinator.isBusy
    }

    private var isLoadingPhotoAttachments: Bool {
        submissionCoordinator.isLoadingPhotos
    }

    private var pendingPhotoAttachmentIDs: Set<PendingPhotoAttachment.ID> {
        Set(pendingPhotoAttachments.map(\.id))
    }

    private var remainingPhotoCapacity: Int {
        submissionCoordinator.remainingPhotoCapacity(
            currentAttachmentIDs: pendingPhotoAttachmentIDs,
            maximumAttachmentCount: maximumPhotoAttachmentCount
        )
    }

    private var canPost: Bool {
        isReplyContextResolved
            && (!content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingPhotoAttachments.isEmpty)
    }

    private var isReplyContextResolved: Bool {
        replyToPostId == nil || resolvedReplyContext != nil
    }

    private var isComposerEnabled: Bool {
        !isBusy && isReplyContextResolved
    }

    private var replyToActor: String? {
        resolvedReplyContext?.authorHandle
    }

    private var effectiveVisibility: GraphQLEnum<HackersPub.PostVisibility> {
        resolvedReplyContext?.visibility ?? publishSettings.visibility
    }

    private var resolvedReplyContext: ReplyContext? {
        guard let replyToPostId,
              let replyContext,
              replyContext.postID == replyToPostId
        else {
            return nil
        }
        return replyContext
    }

    private var resolvedReplyTargetID: String? {
        resolvedReplyContext?.postID
    }

    private var isContentDirty: Bool {
        dirtyState.isContentDirty(currentContent: content)
    }

    private var hasPendingPhotos: Bool {
        !pendingPhotoAttachments.isEmpty
    }

    private var errorMessage: String? {
        presentationCoordinator.errorMessage
    }

    private var visibilityPickerSelection: Binding<GraphQLEnum<HackersPub.PostVisibility>> {
        Binding(
            get: { publishSettings.visibility },
            set: { publishSettings.selectVisibility($0, isBusy: isBusy) }
        )
    }

    private var localePickerSelection: Binding<String> {
        Binding(
            get: { publishSettings.language },
            set: { publishSettings.selectLanguage($0, isBusy: isBusy) }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { presentationCoordinator.isErrorPresented },
            set: { isPresented in
                presentationCoordinator.setErrorPresented(isPresented)
            }
        )
    }

    private var shouldShowMentionSuggestions: Bool {
        activeMention != nil && (isLoadingMentionSuggestions || !mentionSuggestions.isEmpty)
    }

    private let editorTextInset = EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
    private let maximumPhotoAttachmentCount = 10

    let replyToPostId: String?
    let quotedPostId: String?
    let initialMentions: [String]
    private let createNoteDispatcher: ComposeNoteDispatcher

    init(
        replyToPostId: String? = nil,
        quotedPostId: String? = nil,
        initialMentions: [String] = [],
        initialContent: String = "",
        createNoteDispatcher: ComposeNoteDispatcher = .live
    ) {
        self.replyToPostId = replyToPostId
        self.quotedPostId = quotedPostId
        self.initialMentions = initialMentions
        self.createNoteDispatcher = createNoteDispatcher

        let seededContent: String
        if replyToPostId == nil, !self.initialMentions.isEmpty {
            let mentionsText = self.initialMentions.joined(separator: " ")
            seededContent = mentionsText + " " + initialContent
        } else {
            seededContent = initialContent
        }
        _content = State(initialValue: seededContent)
        _dirtyState = State(initialValue: ComposeDirtyState(initialContent: seededContent))

        let defaultLocale = Locale.current.language.languageCode?.identifier ?? "en"
        let storedLocale = UserDefaults.standard.string(forKey: "lastSelectedLocale") ?? defaultLocale
        _publishSettings = State(
            initialValue: ComposePublishSettings(
                language: storedLocale,
                visibility: .case(.public)
            )
        )
    }

    private let availableLocales = [
        "aa", "ab", "ae", "af", "ak", "am", "an", "ar", "as", "av",
        "ay", "az", "ba", "be", "bg", "bh", "bi", "bm", "bn", "bo",
        "br", "bs", "ca", "ce", "ch", "co", "cr", "cs", "cu", "cv",
        "cy", "da", "de", "de-AT", "de-CH", "de-DE", "dv", "dz", "ee",
        "el", "en", "en-AU", "en-CA", "en-GB", "en-IN", "en-US", "eo",
        "es", "es-AR", "es-ES", "es-MX", "et", "eu", "fa", "ff", "fi",
        "fj", "fo", "fr", "fr-CA", "fr-FR", "fy", "ga", "gd", "gl",
        "gn", "gu", "gv", "ha", "he", "hi", "ho", "hr", "ht", "hu",
        "hy", "hz", "ia", "id", "ie", "ig", "ii", "ik", "io", "is",
        "it", "iu", "ja", "jv", "ka", "kg", "ki", "kj", "kk", "kl",
        "km", "kn", "ko", "ko-CN", "ko-KP", "ko-KR", "kr", "ks", "ku",
        "kv", "kw", "ky", "la", "lb", "lg", "li", "ln", "lo", "lt",
        "lu", "lv", "mg", "mh", "mi", "mk", "ml", "mn", "mr", "ms",
        "mt", "my", "na", "nb", "nd", "ne", "ng", "nl", "nn", "no",
        "nr", "nv", "ny", "oc", "oj", "om", "or", "os", "pa", "pi",
        "pl", "ps", "pt", "pt-BR", "pt-PT", "qu", "rm", "rn", "ro",
        "ru", "rw", "sa", "sc", "sd", "se", "sg", "si", "sk", "sl",
        "sm", "sn", "so", "sq", "sr", "ss", "st", "su", "sv", "sw",
        "ta", "te", "tg", "th", "ti", "tk", "tl", "tn", "to", "tr",
        "ts", "tt", "tw", "ty", "ug", "uk", "ur", "uz", "ve", "vi",
        "vo", "wa", "wo", "xh", "yi", "yo", "za", "zh", "zh-CN",
        "zh-HK", "zh-MO", "zh-TW", "zu"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if replyToPostId != nil {
                    ComposeReplyContextStatusView(
                        replyToActor: replyToActor,
                        errorMessage: replyContextErrorMessage,
                        isLoading: isLoadingReplyContext,
                        onRetry: reloadReplyContext
                    )
                }

                if quotedPostId != nil {
                    ComposeQuotedPostSection(
                        post: quotedPostPreview,
                        isLoading: isLoadingQuotedPost,
                        didFailToLoad: didFailToLoadQuotedPost
                    )
                }

                // Editor/Preview toggle
                Picker(NSLocalizedString("compose.mode.edit", comment: "Mode picker"), selection: $showPreview) {
                    Text(NSLocalizedString("compose.mode.edit", comment: "Edit mode")).tag(false)
                    Text(NSLocalizedString("compose.mode.preview", comment: "Preview mode")).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Text editor or preview
                ZStack {
                    if showPreview {
                        ZStack {
                            if content.isEmpty {
                                // Empty state
                                VStack(spacing: 16) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.tertiary)
                                    Text(NSLocalizedString("compose.preview.empty", comment: "Empty preview message"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                // WebView with loading overlay
                                ZStack {
                                    MarkdownPreviewView(html: htmlContent, isLoading: $isLoadingPreview)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .opacity(isLoadingPreview ? 0 : 1)

                                    if isLoadingPreview {
                                        VStack(spacing: 16) {
                                            ProgressView()
                                                .scaleEffect(1.2)
                                            Text(NSLocalizedString("compose.preview.rendering", comment: "Rendering preview message"))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .transition(.opacity)
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        GeometryReader { proxy in
                            ZStack(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text(NSLocalizedString("compose.placeholder", comment: "Compose text placeholder"))
                                        .font(fontSettings.font(for: .body))
                                        .foregroundStyle(.secondary)
                                        .padding(editorTextInset)
                                        .allowsHitTesting(false)
                                }
                                ComposeTextEditor(
                                    text: $content,
                                    selectedRange: $selectedTextRange,
                                    caretRect: $selectedTextCaretRect,
                                    textInset: editorTextInset,
                                    font: fontSettings.uiFont(for: .body),
                                    isEditable: isComposerEnabled
                                )

                                if shouldShowMentionSuggestions {
                                    ComposeMentionSuggestionsPanel(
                                        suggestions: mentionSuggestions,
                                        isLoading: isLoadingMentionSuggestions,
                                        onSelect: insertMention
                                    )
                                    .frame(
                                        width: ComposeMentionPanelPlacement.width(
                                            in: proxy.size.width
                                        ),
                                        alignment: .leading
                                    )
                                    .offset(
                                        x: ComposeMentionPanelPlacement.x(
                                            caretRect: selectedTextCaretRect,
                                            editorWidth: proxy.size.width
                                        ),
                                        y: ComposeMentionPanelPlacement.y(
                                            caretRect: selectedTextCaretRect,
                                            editorHeight: proxy.size.height,
                                            suggestionCount: mentionSuggestions.count
                                        )
                                    )
                                    .zIndex(1)
                                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topLeading)))
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: showPreview)
                .animation(.easeInOut(duration: 0.25), value: isLoadingPreview)

                if !pendingPhotoAttachments.isEmpty || isLoadingPhotoAttachments {
                    ComposePhotoAttachmentsSection(
                        attachments: $pendingPhotoAttachments,
                        isLoading: isLoadingPhotoAttachments,
                        isDisabled: isBusy,
                        onEdit: { id in
                            editingPhotoAttachment = PhotoAttachmentEditorTarget(id: id)
                        },
                        onDelete: removePhotoAttachment
                    )
                }

                Divider()

                // Settings
                VStack(spacing: 12) {
                    if replyToPostId == nil {
                        Picker(
                            NSLocalizedString("compose.visibility", comment: "Visibility picker"),
                            selection: visibilityPickerSelection
                        ) {
                            Text(
                                NSLocalizedString("compose.visibility.public", comment: "Public visibility")
                            )
                            .tag(GraphQLEnum<HackersPub.PostVisibility>.case(.public))
                            Text(
                                NSLocalizedString("compose.visibility.unlisted", comment: "Unlisted visibility")
                            )
                            .tag(GraphQLEnum<HackersPub.PostVisibility>.case(.unlisted))
                            Text(
                                NSLocalizedString("compose.visibility.followers", comment: "Followers visibility")
                            )
                            .tag(GraphQLEnum<HackersPub.PostVisibility>.case(.followers))
                        }
                        .pickerStyle(.segmented)
                    } else if let replyContext = resolvedReplyContext {
                        HStack {
                            Text(NSLocalizedString("compose.visibility", comment: "Visibility picker"))
                            Spacer()
                            Label(
                                ComposeReplyVisibilityPresentation.title(
                                    for: replyContext.visibility
                                ),
                                systemImage: "lock.fill"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Language picker
                    Picker(
                        NSLocalizedString("compose.language", comment: "Language picker"),
                        selection: localePickerSelection
                    ) {
                        ForEach(availableLocales, id: \.self) { locale in
                            Text(localeDisplayName(for: locale)).tag(locale)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding()
                .disabled(isBusy)
            }
            .navigationTitle(replyToPostId != nil ? NSLocalizedString("nav.reply", comment: "Reply navigation title") : NSLocalizedString("nav.newPost", comment: "New post navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .task(id: quotedPostId) {
                await fetchQuotedPostPreview()
            }
            .task(id: replyToPostId) {
                await reloadReplyContext()
            }
            .onChange(of: content) { _, newValue in
                detectAndUpdateLanguage(from: newValue)
                scheduleMentionSearch()
            }
            .onChange(of: selectedTextRange) { _, _ in
                scheduleMentionSearch()
            }
            .onChange(of: showPreview) { _, isPreviewing in
                if isPreviewing {
                    clearMentionSuggestions()
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty,
                      let selection = submissionCoordinator.preparePhotoSelection(
                          items: newItems,
                          currentAttachmentIDs: pendingPhotoAttachmentIDs,
                          maximumAttachmentCount: maximumPhotoAttachmentCount
                      )
                else {
                    selectedPhotoItems = []
                    return
                }
                selectedPhotoItems = []
                Task {
                    defer { submissionCoordinator.finishPhotoLoading(selection.token) }
                    await loadPhotoAttachments(from: selection)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        requestDismiss()
                    }
                    label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(NSLocalizedString("compose.cancel", comment: "Cancel button"))
                    .disabled(isBusy)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: max(1, remainingPhotoCapacity),
                        matching: .images
                    ) {
                        Image(systemName: "photo.badge.plus")
                    }
                    .accessibilityLabel(NSLocalizedString("compose.photos.add", comment: "Add photos button"))
                    .disabled(isBusy || !isReplyContextResolved || remainingPhotoCapacity == 0)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        preparePost()
                    } label: {
                        Label(NSLocalizedString("compose.post", comment: "Post button"), systemImage: "paperplane")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel(NSLocalizedString("compose.post", comment: "Post button"))
                    .disabled(!canPost || isBusy)
                }
            }
            .alert(
                NSLocalizedString("compose.error.title", comment: "Error alert title"),
                isPresented: errorAlertBinding
            ) {
                Button(NSLocalizedString("compose.error.ok", comment: "OK button")) {
                    presentationCoordinator.setErrorPresented(false)
                }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if submissionCoordinator.isSubmitting {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .sheet(item: $editingPhotoAttachment) { target in
                if let index = pendingPhotoAttachments.firstIndex(where: { $0.id == target.id }) {
                    ComposePhotoAttachmentDetailsSheet(
                        attachment: $pendingPhotoAttachments[index]
                    )
                }
            }
            .confirmationDialog(
                NSLocalizedString("compose.discard.title", comment: "Discard compose title"),
                isPresented: $presentationCoordinator.showsDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    NSLocalizedString("compose.discard.action", comment: "Discard compose action"),
                    role: .destructive
                ) {
                    dismiss()
                }
                Button(NSLocalizedString("compose.cancel", comment: "Cancel button"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("compose.discard.message", comment: "Discard compose message"))
            }
            .interactiveDismissDisabled(
                presentationCoordinator.interactiveDismissDisabled(
                    isContentDirty: isContentDirty,
                    hasPhotos: hasPendingPhotos,
                    isBusy: isBusy
                )
            )
        }
    }

    private static let replyMentionPageSize: Int32 = 50

    private func reloadReplyContext() async {
        guard let replyToPostId else { return }

        let requestID = UUID()
        replyContextRequestID = requestID
        replyContext = nil
        replyContextErrorMessage = nil
        isLoadingReplyContext = true

        let outcome = await loadReplyContext(
            postID: replyToPostId,
            currentViewerHandle: authManager.currentAccount?.handle,
            isCurrent: {
                replyContextRequestID == requestID && self.replyToPostId == replyToPostId
            },
            fetchPage: { cursor in
                try await fetchReplyContextPage(postID: replyToPostId, after: cursor)
            }
        )

        guard replyContextRequestID == requestID else { return }
        isLoadingReplyContext = false

        switch outcome {
        case let .loaded(context):
            replyContext = context
            seedReplyMentions(context.mentionHandles, requestID: requestID)
        case let .failed(message):
            replyContextErrorMessage = message
        case .ignored:
            break
        }
    }

    private func fetchReplyContextPage(postID: String, after: String?) async throws -> ReplyContextPage {
        let afterValue: GraphQLNullable<String> = after.map { .some($0) } ?? .none
        let response = try await apolloClient.fetch(
            query: HackersPub.ReplyContextQuery(
                id: postID,
                after: afterValue,
                first: Self.replyMentionPageSize
            ),
            cachePolicy: .networkOnly
        )
        if let error = response.errors?.first {
            throw ReplyContextLoadError.requestFailed(
                error.message
                    ?? NSLocalizedString(
                        "compose.reply.contextUnavailable",
                        comment: "Reply context unavailable"
                    )
            )
        }
        guard let post = response.data?.node?.asPost else {
            throw ReplyContextLoadError.missingPost
        }

        return ReplyContextPage(
            postID: post.id,
            visibility: post.visibility,
            authorHandle: post.actor.handle,
            mentionHandles: post.mentions.edges.map { $0.node.handle },
            hasNextPage: post.mentions.pageInfo.hasNextPage,
            endCursor: post.mentions.pageInfo.endCursor
        )
    }

    private func seedReplyMentions(_ handles: [String], requestID: UUID) {
        content = dirtyState.applyReplyMentionSeed(
            handles: handles,
            currentContent: content,
            isCurrent: replyContextRequestID == requestID && !Task.isCancelled
        )
    }

    private func localeDisplayName(for localeCode: String) -> String {
        let locale = Locale(identifier: localeCode)
        if let displayName = locale.localizedString(forIdentifier: localeCode) {
            return "\(displayName) (\(localeCode))"
        }
        return localeCode
    }

    private func requestDismiss() {
        let action = presentationCoordinator.requestDismiss(
            isContentDirty: isContentDirty,
            hasPhotos: hasPendingPhotos,
            isBusy: isBusy
        )
        if action == .dismiss {
            dismiss()
        }
    }

    private func detectAndUpdateLanguage(from text: String) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominantLanguage = recognizer.dominantLanguage else { return }
        let languageCode = dominantLanguage.rawValue
        if availableLocales.contains(languageCode) {
            publishSettings.applyAutomaticLanguage(languageCode, isBusy: isBusy)
        } else {
            let baseLanguage = String(languageCode.prefix(2))
            if availableLocales.contains(baseLanguage) {
                publishSettings.applyAutomaticLanguage(baseLanguage, isBusy: isBusy)
            }
        }
    }

    private func scheduleMentionSearch() {
        mentionSearchTask?.cancel()

        guard !showPreview,
              !isBusy,
              let mention = ComposeMentionSupport.activeMention(
                  in: content,
                  selectedRange: selectedTextRange
              )
        else {
            clearMentionSuggestions()
            return
        }

        activeMention = mention
        isLoadingMentionSuggestions = true

        mentionSearchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }

                let response = try await apolloClient.fetch(
                    query: HackersPub.SearchActorsByHandleQuery(prefix: mention.query, limit: .some(10)),
                    cachePolicy: .networkOnly
                )

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard activeMention == mention else { return }
                    mentionSuggestions = response.data?.searchActorsByHandle ?? []
                    isLoadingMentionSuggestions = false
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard activeMention == mention else { return }
                    mentionSuggestions = []
                    isLoadingMentionSuggestions = false
                }
            }
        }
    }

    private func insertMention(_ actor: HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle) {
        guard let activeMention else { return }

        let normalizedHandle = actor.handle.hasPrefix("@")
            ? String(actor.handle.dropFirst())
            : actor.handle
        let replacement = "@\(normalizedHandle) "
        let replacementRange = ComposeMentionSupport.replacementRange(
            in: content,
            mention: activeMention
        )
        replaceText(in: replacementRange, with: replacement)
        clearMentionSuggestions()
    }

    private func clearMentionSuggestions() {
        mentionSearchTask?.cancel()
        activeMention = nil
        mentionSuggestions = []
        isLoadingMentionSuggestions = false
    }

    @discardableResult
    private func replaceText(in range: NSRange, with replacement: String) -> NSRange {
        let nsContent = content as NSString
        let location = max(0, min(range.location, nsContent.length))
        let length = max(0, min(range.length, nsContent.length - location))
        let boundedRange = NSRange(location: location, length: length)

        if let stringRange = Range(boundedRange, in: content) {
            content.replaceSubrange(stringRange, with: replacement)
        } else {
            content.append(replacement)
        }

        let newLocation = location + (replacement as NSString).length
        let newRange = NSRange(location: newLocation, length: 0)
        selectedTextRange = newRange
        return newRange
    }

    private func fetchQuotedPostPreview() async {
        guard let quotedPostId else { return }
        isLoadingQuotedPost = true
        didFailToLoadQuotedPost = false
        defer { isLoadingQuotedPost = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.PostDetailQuery(id: quotedPostId, repliesAfter: nil),
                cachePolicy: .networkOnly
            )
            guard let quotedPost = response.data?.node?.asPost else {
                quotedPostPreview = nil
                didFailToLoadQuotedPost = true
                return
            }
            quotedPostPreview = quotedPost
        } catch {
            composeLogger.error("Unable to fetch quoted note preview")
            quotedPostPreview = nil
            didFailToLoadQuotedPost = true
        }
    }

    private func loadPhotoAttachments(
        from selection: ComposePreparedPhotoSelection<PhotosPickerItem>
    ) async {
        var feedback = ComposePhotoLoadFeedback(
            omittedForLimitCount: selection.omittedForLimitCount
        )
        var loadedAttachments: [PendingPhotoAttachment] = []

        for item in selection.items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else {
                    feedback.recordFailure()
                    continue
                }
                loadedAttachments.append(PendingPhotoAttachment(data: data, image: image))
            } catch is CancellationError {
                return
            } catch {
                feedback.recordFailure()
                composeLogger.error("Unable to load photo attachment")
            }
        }

        guard let attachmentsToAppend = submissionCoordinator.loadedPhotosToAppend(
            loadedAttachments,
            for: selection.token,
            currentAttachmentIDs: pendingPhotoAttachmentIDs
        ) else {
            return
        }

        pendingPhotoAttachments.append(contentsOf: attachmentsToAppend)
        if let message = feedback.localizedMessage() {
            presentationCoordinator.showError(message)
        }
    }

    private func removePhotoAttachment(id: PendingPhotoAttachment.ID) {
        pendingPhotoAttachments.removeAll { $0.id == id }
    }

    private func uploadPhotoAttachments(
        snapshot: [PendingPhotoAttachment]
    ) async throws -> [HackersPub.CreateNoteMediumInput] {
        let adapter = ComposePhotoAttachmentUploadAdapter(
            attachments: $pendingPhotoAttachments
        )
        return try await adapter.upload(snapshot: snapshot) { attachment in
            let uploaded = try await MediumUploadService.shared.uploadImageData(attachment.data)
            return uploaded.id
        }
    }

    private enum NoteSubmissionResult {
        case created(noteID: String)
        case invalidInput(inputPath: String)
        case notAuthenticated
        case failed

        var presentationResult: ComposeNoteSubmissionResult {
            switch self {
            case .created:
                return .success
            case let .invalidInput(inputPath):
                return .invalidInput(inputPath: inputPath)
            case .notAuthenticated:
                return .notAuthenticated
            case .failed:
                return .failed
            }
        }
    }

    private struct PreparedNoteSubmission {
        let settings: ComposePreparedPublishSettings
        let attachments: [PendingPhotoAttachment]
        let replyTargetID: String?
        let submit: ([HackersPub.CreateNoteMediumInput]) async throws -> NoteSubmissionResult
    }

    private func preparePost() {
        guard canPost else { return }

        do {
            guard let prepared = try submissionCoordinator.prepareSubmission({ revision in
                // The coordinator owns the permit before this snapshot is created.
                try makePreparedNoteSubmission(revision: revision)
            }) else {
                return
            }

            Task {
                await post(prepared)
            }
        } catch ComposeNoteDispatchError.unsupportedVisibility {
            presentationCoordinator.showError(
                ComposeNoteDispatchError.unsupportedVisibility.localizedDescription
            )
        } catch {
            composeLogger.error("Unable to prepare note submission")
            presentationCoordinator.showError(
                NSLocalizedString("compose.error.failed", comment: "Failed to create note")
            )
        }
    }

    private func makePreparedNoteSubmission(
        revision: ComposeSubmissionRevision
    ) throws -> PreparedNoteSubmission {
        let preparedSettings = publishSettings.prepared(
            content: content,
            effectiveVisibility: effectiveVisibility,
            revision: revision
        )
        let preparedReplyTargetID = resolvedReplyTargetID
        let preparedQuotedPostID = quotedPostId
        let preparedAttachments = pendingPhotoAttachments

        guard isSupportedCreateNoteVisibility(preparedSettings.visibility) else {
            throw ComposeNoteDispatchError.unsupportedVisibility
        }

        let submit: (
            [HackersPub.CreateNoteMediumInput]
        ) async throws -> NoteSubmissionResult = { media in
            let outcome = try await createNoteDispatcher.submit(
                CreateNoteDispatchRequest(
                    content: preparedSettings.content,
                    language: preparedSettings.language,
                    visibility: preparedSettings.visibility,
                    media: media,
                    replyTargetID: preparedReplyTargetID,
                    quotedPostID: preparedQuotedPostID
                )
            )

            switch outcome {
            case let .created(id: noteID):
                return .created(noteID: noteID)
            case let .invalidInput(inputPath):
                return .invalidInput(inputPath: inputPath)
            case .notAuthenticated:
                return .notAuthenticated
            case .failed:
                return .failed
            }
        }
        return PreparedNoteSubmission(
            settings: preparedSettings,
            attachments: preparedAttachments,
            replyTargetID: preparedReplyTargetID,
            submit: submit
        )
    }

    private func post(_ prepared: ComposePreparedSubmission<PreparedNoteSubmission>) async {
        do {
            let outcome = try await submissionCoordinator.perform(
                prepared,
                upload: { preparedNote in
                    try await uploadPhotoAttachments(snapshot: preparedNote.attachments)
                },
                submit: { preparedNote, media in
                    try await preparedNote.submit(media)
                }
            )
            guard case let .completed(result) = outcome else { return }

            let action = presentationCoordinator.handleSubmissionResult(result.presentationResult)
            guard action == .dismiss,
                  case let .created(noteID) = result
            else {
                return
            }

            composeLogger.info("Published note")
            if let localeToPersist = prepared.value.settings.localeToPersist(
                after: result.presentationResult,
                successfulRevision: prepared.revision,
                comparedTo: lastSelectedLocale
            ) {
                lastSelectedLocale = localeToPersist
            }
            if let event = PostContentEvent.replyCreated(
                createdPostID: noteID,
                replyTargetID: prepared.value.replyTargetID
            ) {
                PostContentEventCenter.publish(event)
            } else {
                NotificationCenter.default.post(name: Notification.Name("RefreshTimeline"), object: nil)
            }
            dismiss()
        } catch is CancellationError {
            composeLogger.info("Cancelled note submission")
        } catch ComposeNoteDispatchError.unsupportedVisibility {
            presentationCoordinator.showError(
                ComposeNoteDispatchError.unsupportedVisibility.localizedDescription
            )
        } catch {
            composeLogger.error("Unable to create note")
            presentationCoordinator.showError(
                NSLocalizedString("compose.error.failed", comment: "Failed to create note")
            )
        }
    }
}
