import SwiftUI
@preconcurrency import Apollo
import Kingfisher
import Markdown
import NaturalLanguage
import PhotosUI
import UIKit

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var fontSettings = FontSettingsManager.shared
    @State private var content: String
    @State private var selectedTextRange = NSRange(location: 0, length: 0)
    @State private var selectedTextCaretRect: CGRect = .zero
    @State private var visibility: GraphQLEnum<HackersPub.PostVisibility> = .case(.public)
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showPreview = false
    @State private var isLoadingPreview = false
    @State private var quotedPostPreview: HackersPub.PostDetailQuery.Data.Node.AsPost?
    @State private var isLoadingQuotedPost = false
    @State private var didFailToLoadQuotedPost = false
    @State private var activeMention: ActiveMention?
    @State private var mentionSuggestions: [HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle] = []
    @State private var isLoadingMentionSuggestions = false
    @State private var mentionSearchTask: Task<Void, Never>?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingPhotoAttachments: [PendingPhotoAttachment] = []
    @State private var editingPhotoAttachment: PendingPhotoAttachmentEditorTarget?
    @State private var isLoadingPhotoAttachments = false
    @AppStorage("lastSelectedLocale") private var lastSelectedLocale: String = {
        Locale.current.language.languageCode?.identifier ?? "en"
    }()

    private var htmlContent: String {
        let document = Document(parsing: content)
        let rawHTML = HTMLFormatter.format(document)
        return HTMLStyles.wrapHTML(rawHTML, css: HTMLStyles.composePreviewCSS)
    }

    private var isBusy: Bool {
        isPosting || isLoadingPhotoAttachments
    }

    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingPhotoAttachments.isEmpty
    }

    private var shouldShowMentionSuggestions: Bool {
        activeMention != nil && (isLoadingMentionSuggestions || !mentionSuggestions.isEmpty)
    }

    private let editorTextInset = EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)

    let replyToPostId: String?
    let quotedPostId: String?
    let replyToActor: String?
    let initialMentions: [String]

    init(
        replyToPostId: String? = nil,
        quotedPostId: String? = nil,
        replyToActor: String? = nil,
        initialMentions: [String] = []
    ) {
        self.replyToPostId = replyToPostId
        self.quotedPostId = quotedPostId
        self.replyToActor = replyToActor
        self.initialMentions = initialMentions
        
        // 초기 멘션 목록이 있으면 content에 자동으로 추가
        if !self.initialMentions.isEmpty {
            let mentionsText = self.initialMentions.joined(separator: " ")
            _content = State(initialValue: mentionsText + " ")
        } else {
            _content = State(initialValue: "")
        }
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
                // Reply indicator
                if let replyToActor {
                    HStack {
                        Text(String(format: NSLocalizedString("compose.replyingTo", comment: "Replying to label"), replyToActor))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        Spacer()
                    }
                }

                if quotedPostId != nil {
                    quoteTargetSection
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
                                    isEditable: !isBusy
                                )

                                if shouldShowMentionSuggestions {
                                    MentionSuggestionsPanel(
                                        suggestions: mentionSuggestions,
                                        isLoading: isLoadingMentionSuggestions,
                                        onSelect: insertMention
                                    )
                                    .frame(width: mentionPanelWidth(in: proxy.size.width), alignment: .leading)
                                    .offset(
                                        x: mentionPanelX(in: proxy.size.width),
                                        y: mentionPanelY(in: proxy.size.height)
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
                    photoAttachmentsSection
                }

                Divider()

                // Settings
                VStack(spacing: 12) {
                    // Visibility picker
                    Picker(NSLocalizedString("compose.visibility", comment: "Visibility picker"), selection: $visibility) {
                        Text(NSLocalizedString("compose.visibility.public", comment: "Public visibility")).tag(GraphQLEnum<HackersPub.PostVisibility>.case(.public))
                        Text(NSLocalizedString("compose.visibility.unlisted", comment: "Unlisted visibility")).tag(GraphQLEnum<HackersPub.PostVisibility>.case(.unlisted))
                        Text(NSLocalizedString("compose.visibility.followers", comment: "Followers visibility")).tag(GraphQLEnum<HackersPub.PostVisibility>.case(.followers))
                    }
                    .pickerStyle(.segmented)

                    // Language picker
                    Picker(NSLocalizedString("compose.language", comment: "Language picker"), selection: $lastSelectedLocale) {
                        ForEach(availableLocales, id: \.self) { locale in
                            Text(localeDisplayName(for: locale)).tag(locale)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding()
            }
            .navigationTitle(replyToPostId != nil ? NSLocalizedString("nav.reply", comment: "Reply navigation title") : NSLocalizedString("nav.newPost", comment: "New post navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .task(id: quotedPostId) {
                await fetchQuotedPostPreview()
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
                guard !newItems.isEmpty else { return }
                Task {
                    await loadPhotoAttachments(from: newItems)
                    selectedPhotoItems = []
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
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
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Image(systemName: "photo.badge.plus")
                    }
                    .accessibilityLabel(NSLocalizedString("compose.photos.add", comment: "Add photos button"))
                    .disabled(isBusy)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await post()
                        }
                    } label: {
                        Label(NSLocalizedString("compose.post", comment: "Post button"), systemImage: "paperplane")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel(NSLocalizedString("compose.post", comment: "Post button"))
                    .disabled(!canPost || isBusy)
                }
            }
            .alert(NSLocalizedString("compose.error.title", comment: "Error alert title"), isPresented: .constant(errorMessage != nil)) {
                Button(NSLocalizedString("compose.error.ok", comment: "OK button")) {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if isPosting {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .sheet(item: $editingPhotoAttachment) { target in
                if let index = pendingPhotoAttachments.firstIndex(where: { $0.id == target.id }) {
                    PhotoAttachmentDetailsSheet(attachment: $pendingPhotoAttachments[index])
                }
            }
        }
    }

    @ViewBuilder
    private var photoAttachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(NSLocalizedString("compose.photos.title", comment: "Selected photos title"), systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isLoadingPhotoAttachments {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach($pendingPhotoAttachments) { $attachment in
                        PendingPhotoAttachmentView(
                            attachment: $attachment,
                            onEdit: {
                                editingPhotoAttachment = PendingPhotoAttachmentEditorTarget(id: attachment.id)
                            },
                            onDelete: {
                                removePhotoAttachment(id: attachment.id)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.06))
    }

    @ViewBuilder
    private var quoteTargetSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "quote.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("compose.quoting", comment: "Quoting indicator title"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if isLoadingQuotedPost && quotedPostPreview == nil {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("compose.quotingLoading", comment: "Loading quoted post message"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } else if let quotedPostPreview {
                HStack(alignment: .top, spacing: 10) {
                    KFImage(URL(string: quotedPostPreview.actor.avatarUrl))
                        .placeholder {
                            Color.gray.opacity(0.2)
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        if let name = quotedPostPreview.actor.name {
                            HTMLTextView(html: name, font: .caption)
                                .lineLimit(1)
                        }
                        Text(quotedPostPreview.actor.handle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(quotedPostPreview.excerpt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 10)
            } else if didFailToLoadQuotedPost {
                Text(NSLocalizedString("compose.quotingUnavailable", comment: "Unable to load quoted post message"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private func localeDisplayName(for localeCode: String) -> String {
        let locale = Locale(identifier: localeCode)
        if let displayName = locale.localizedString(forIdentifier: localeCode) {
            return "\(displayName) (\(localeCode))"
        }
        return localeCode
    }

    private func detectAndUpdateLanguage(from text: String) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        // Get the dominant language
        if let dominantLanguage = recognizer.dominantLanguage {
            let languageCode = dominantLanguage.rawValue

            if availableLocales.contains(languageCode) {
                lastSelectedLocale = languageCode
            } else {
                // Try to find a matching base language (e.g., "en" for "en-US")
                let baseLanguage = String(languageCode.prefix(2))
                if availableLocales.contains(baseLanguage) {
                    lastSelectedLocale = baseLanguage
                }
            }
        }
    }

    private func scheduleMentionSearch() {
        mentionSearchTask?.cancel()

        guard !showPreview, !isBusy, let mention = currentMentionTrigger() else {
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

    private func currentMentionTrigger() -> ActiveMention? {
        let nsContent = content as NSString
        let cursor = max(0, min(selectedTextRange.location, nsContent.length))
        guard selectedTextRange.length == 0, cursor > 0 else { return nil }

        let beforeCursor = nsContent.substring(to: cursor) as NSString
        var searchLength = beforeCursor.length

        while searchLength > 0 {
            let atRange = beforeCursor.range(
                of: "@",
                options: .backwards,
                range: NSRange(location: 0, length: searchLength)
            )
            guard atRange.location != NSNotFound else { return nil }

            let startsAtBoundary: Bool
            if atRange.location > 0 {
                let previous = beforeCursor.character(at: atRange.location - 1)
                startsAtBoundary = isMentionBoundary(previous)
            } else {
                startsAtBoundary = true
            }

            guard startsAtBoundary else {
                searchLength = atRange.location
                continue
            }

            let queryLocation = atRange.location + 1
            let queryLength = cursor - queryLocation
            guard queryLength > 0 else { return nil }

            let query = beforeCursor.substring(with: NSRange(location: queryLocation, length: queryLength))
            guard isValidMentionQuery(query) else {
                return nil
            }

            return ActiveMention(
                query: query,
                range: NSRange(location: atRange.location, length: cursor - atRange.location)
            )
        }

        return nil
    }

    private var mentionQuerySeparators: CharacterSet {
        CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "<>()[]{}\"'`,!?;:"))
    }

    private var mentionPanelEstimatedHeight: CGFloat {
        if mentionSuggestions.isEmpty {
            return 52
        }
        return min(CGFloat(mentionSuggestions.count) * MentionSuggestionsPanel.rowHeight, MentionSuggestionsPanel.maxListHeight)
    }

    private func mentionPanelWidth(in editorWidth: CGFloat) -> CGFloat {
        max(220, min(editorWidth, 380))
    }

    private func mentionPanelX(in editorWidth: CGFloat) -> CGFloat {
        let panelWidth = mentionPanelWidth(in: editorWidth)
        let proposedX = selectedTextCaretRect.minX - 8
        return min(max(0, proposedX), max(0, editorWidth - panelWidth))
    }

    private func mentionPanelY(in editorHeight: CGFloat) -> CGFloat {
        let proposedY = selectedTextCaretRect.maxY + 14
        let maxY = max(8, editorHeight - mentionPanelEstimatedHeight - 8)
        return min(max(8, proposedY), maxY)
    }

    private func isValidMentionQuery(_ query: String) -> Bool {
        guard query.count <= 80,
              query.rangeOfCharacter(from: mentionQuerySeparators) == nil
        else {
            return false
        }

        let handleParts = query.split(separator: "@", omittingEmptySubsequences: false)
        guard (1...2).contains(handleParts.count),
              let username = handleParts.first,
              isValidMentionUsernamePart(String(username))
        else {
            return false
        }

        if handleParts.count == 2 {
            return handleParts[1].isEmpty || isValidMentionHostPrefix(String(handleParts[1]))
        }

        return true
    }

    private func isMentionBoundary(_ utf16Value: unichar) -> Bool {
        guard let scalar = UnicodeScalar(Int(utf16Value)) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
            || CharacterSet(charactersIn: "([{").contains(scalar)
    }

    private func isValidMentionUsernamePart(_ username: String) -> Bool {
        guard !username.isEmpty else { return false }

        let scalars = Array(username.unicodeScalars)
        for (index, scalar) in scalars.enumerated() {
            if isASCIILetterOrDigit(scalar) || scalar == "_" {
                continue
            }

            if (scalar == "." || scalar == "-"),
               index > 0,
               index < scalars.count - 1 {
                continue
            }

            return false
        }

        return true
    }

    private func isValidMentionHostPrefix(_ host: String) -> Bool {
        guard host.count <= 253 else { return false }

        for scalar in host.unicodeScalars {
            guard isASCIILetterOrDigit(scalar) || scalar == "-" || scalar == "." else {
                return false
            }
        }

        return true
    }

    private func isASCIILetterOrDigit(_ scalar: UnicodeScalar) -> Bool {
        (65...90).contains(Int(scalar.value))
            || (97...122).contains(Int(scalar.value))
            || (48...57).contains(Int(scalar.value))
    }

    private func insertMention(_ actor: HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle) {
        guard let activeMention else { return }

        let normalizedHandle = actor.handle.hasPrefix("@")
            ? String(actor.handle.dropFirst())
            : actor.handle
        let replacement = "@\(normalizedHandle) "
        let replacementRange = mentionReplacementRange(for: activeMention)
        replaceText(in: replacementRange, with: replacement)
        clearMentionSuggestions()
    }

    private func mentionReplacementRange(for mention: ActiveMention) -> NSRange {
        let nsContent = content as NSString
        var end = min(mention.range.location + mention.range.length, nsContent.length)

        while end < nsContent.length {
            let character = nsContent.character(at: end)
            guard !CharacterSet.whitespacesAndNewlines.containsUnicodeScalar(character) else {
                end += 1
                while end < nsContent.length,
                      CharacterSet.whitespacesAndNewlines.containsUnicodeScalar(nsContent.character(at: end)) {
                    end += 1
                }
                break
            }

            let currentQuery = nsContent.substring(
                with: NSRange(location: mention.range.location + 1, length: end - mention.range.location - 1)
            )
            guard isMentionContinuationCharacter(character, after: currentQuery) else { break }
            end += 1
        }

        return NSRange(location: mention.range.location, length: end - mention.range.location)
    }

    private func isMentionContinuationCharacter(_ utf16Value: unichar, after currentQuery: String) -> Bool {
        guard let scalar = UnicodeScalar(Int(utf16Value)) else { return false }

        let parts = currentQuery.split(separator: "@", omittingEmptySubsequences: false)
        if parts.count == 1 {
            if isASCIILetterOrDigit(scalar) || scalar == "_" || scalar == "-" {
                return true
            }
            return scalar == "@" && !currentQuery.isEmpty
        }

        guard parts.count == 2 else { return false }
        return isASCIILetterOrDigit(scalar) || scalar == "-" || scalar == "."
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
            print("Error fetching quoted post preview: \(error)")
            quotedPostPreview = nil
            didFailToLoadQuotedPost = true
        }
    }

    private func loadPhotoAttachments(from items: [PhotosPickerItem]) async {
        isLoadingPhotoAttachments = true
        defer { isLoadingPhotoAttachments = false }

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else {
                    continue
                }
                pendingPhotoAttachments.append(PendingPhotoAttachment(data: data, image: image))
            } catch {
                print("Error loading photo attachment: \(error)")
                errorMessage = String(format: NSLocalizedString("compose.photos.error.loadFailed", comment: "Photo load failure"), error.localizedDescription)
            }
        }
    }

    private func removePhotoAttachment(id: PendingPhotoAttachment.ID) {
        pendingPhotoAttachments.removeAll { $0.id == id }
    }

    private func uploadPhotoAttachments() async throws -> [HackersPub.CreateNoteMediumInput] {
        var media: [HackersPub.CreateNoteMediumInput] = []
        for attachment in pendingPhotoAttachments {
            let uploaded = try await MediumUploadService.shared.uploadImageData(attachment.data)
            media.append(
                HackersPub.CreateNoteMediumInput(
                    alt: attachment.alt.trimmingCharacters(in: .whitespacesAndNewlines),
                    mediumId: uploaded.id
                )
            )
        }
        return media
    }

    private func post() async {
        isPosting = true
        defer { isPosting = false }

        do {
            let media = try await uploadPhotoAttachments()
            let response = try await apolloClient.perform(
                mutation: HackersPub.CreateNoteMutation(
                    content: content,
                    language: lastSelectedLocale,
                    visibility: visibility,
                    media: media.isEmpty ? [] : .some(media),
                    replyTargetId: replyToPostId.map { .some($0) } ?? nil,
                    quotedPostId: quotedPostId.map { .some($0) } ?? nil
                )
            )

            if let payload = response.data?.createNote.asCreateNotePayload {
                // Success - notify timelines to refresh and dismiss the view
                print("Posted note: \(payload.note.id)")
                NotificationCenter.default.post(name: Notification.Name("RefreshTimeline"), object: nil)
                dismiss()
            } else if let invalidInput = response.data?.createNote.asInvalidInputError {
                errorMessage = String(format: NSLocalizedString("compose.error.invalidInput", comment: "Invalid input error"), invalidInput.inputPath)
            } else if response.data?.createNote.asNotAuthenticatedError != nil {
                errorMessage = NSLocalizedString("compose.error.notAuthenticated", comment: "Not authenticated error")
            } else {
                errorMessage = NSLocalizedString("compose.error.failed", comment: "Failed to create post error")
            }
        } catch {
            print("Error creating note: \(error)")
            errorMessage = String(format: NSLocalizedString("compose.error.failedWithDetails", comment: "Failed to create post error with details"), error.localizedDescription)
        }
    }
}

private struct PendingPhotoAttachment: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let image: UIImage
    var alt = ""
}

private struct PendingPhotoAttachmentEditorTarget: Identifiable {
    let id: PendingPhotoAttachment.ID
}

private struct PendingPhotoAttachmentView: View {
    @Binding var attachment: PendingPhotoAttachment
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: attachment.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 156, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .clipped()

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.62))
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel(NSLocalizedString("compose.photos.delete", comment: "Delete photo button"))
            }

            Button(action: onEdit) {
                HStack(spacing: 6) {
                    SwiftUI.Image(systemName: attachment.alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "text.badge.plus" : "checkmark.circle.fill")
                        .foregroundStyle(attachment.alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SwiftUI.Color.secondary : SwiftUI.Color.green)
                    Text(
                        attachment.alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? NSLocalizedString("compose.photos.alt.add", comment: "Add alt text")
                            : attachment.alt
                    )
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 176, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PhotoAttachmentDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var attachment: PendingPhotoAttachment

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(uiImage: attachment.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section {
                    TextField(
                        NSLocalizedString("compose.photos.altPlaceholder", comment: "Photo alt text placeholder"),
                        text: $attachment.alt,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                } footer: {
                    Text(NSLocalizedString("compose.photos.alt.footer", comment: "Alt text guidance"))
                }
            }
            .navigationTitle(NSLocalizedString("compose.photos.details", comment: "Photo details title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("settings.done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ActiveMention: Equatable {
    let query: String
    let range: NSRange

    static func == (lhs: ActiveMention, rhs: ActiveMention) -> Bool {
        lhs.query == rhs.query
            && lhs.range.location == rhs.range.location
            && lhs.range.length == rhs.range.length
    }
}

private struct MentionSuggestionsPanel: View {
    static let rowHeight: CGFloat = 62
    static let maxListHeight: CGFloat = 248

    let suggestions: [HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle]
    let isLoading: Bool
    let onSelect: (HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle) -> Void

    private var listHeight: CGFloat {
        min(CGFloat(suggestions.count) * Self.rowHeight, Self.maxListHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading && suggestions.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(NSLocalizedString("compose.mentions.searching", comment: "Mention search loading status"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
            }

            if !suggestions.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \.id) { actor in
                            Button {
                                onSelect(actor)
                            } label: {
                                MentionSuggestionRow(actor: actor)
                            }
                            .buttonStyle(.plain)

                            if actor.id != suggestions.last?.id {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
                .frame(height: listHeight)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
    }
}

private struct MentionSuggestionRow: View {
    let actor: HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle

    var body: some View {
        HStack(spacing: 10) {
            KFImage(URL(string: actor.avatarUrl))
                .placeholder {
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                        }
                }
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let name = actor.name, !name.isEmpty {
                    HTMLTextView(html: name, font: .subheadline)
                        .lineLimit(1)
                } else {
                    Text(actor.handle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Text(actor.handle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct ComposeTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var caretRect: CGRect
    let textInset: EdgeInsets
    let font: UIFont
    let isEditable: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.adjustsFontForContentSizeCategory = false
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            textView.text = text
        }

        if textView.font != font {
            textView.font = font
        }

        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(textInset)
        textView.isEditable = isEditable
        textView.isSelectable = true

        let boundedRange = selectedRange.bounded(to: textView.text.utf16.count)
        if textView.selectedRange != boundedRange {
            textView.selectedRange = boundedRange
        }

        context.coordinator.updateCaretRect(textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ComposeTextEditor

        init(parent: ComposeTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            updateCaretRect(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
            updateCaretRect(textView)
        }

        func updateCaretRect(_ textView: UITextView) {
            let textRange = textView.selectedTextRange
                ?? textView.textRange(from: textView.endOfDocument, to: textView.endOfDocument)
            guard let textRange else { return }

            let rect = textView.caretRect(for: textRange.start)
            guard rect.isFinite, rect != parent.caretRect else { return }

            DispatchQueue.main.async { [parent] in
                parent.caretRect = rect
            }
        }
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
    }
}

private extension UIEdgeInsets {
    init(_ edgeInsets: EdgeInsets) {
        self.init(
            top: edgeInsets.top,
            left: edgeInsets.leading,
            bottom: edgeInsets.bottom,
            right: edgeInsets.trailing
        )
    }
}

private extension CharacterSet {
    func containsUnicodeScalar(_ utf16Value: unichar) -> Bool {
        guard let scalar = UnicodeScalar(Int(utf16Value)) else { return false }
        return contains(scalar)
    }
}

private extension NSRange {
    func bounded(to upperBound: Int) -> NSRange {
        let location = max(0, min(location, upperBound))
        let length = max(0, min(length, upperBound - location))
        return NSRange(location: location, length: length)
    }
}
