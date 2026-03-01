import SwiftUI
@preconcurrency import Apollo
import Kingfisher
import Markdown
import NaturalLanguage

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var fontSettings = FontSettingsManager.shared
    @State private var content: String
    @State private var visibility: GraphQLEnum<HackersPub.PostVisibility> = .case(.public)
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showPreview = false
    @State private var isLoadingPreview = false
    @State private var quotedPostPreview: HackersPub.PostDetailQuery.Data.Node.AsPost?
    @State private var isLoadingQuotedPost = false
    @State private var didFailToLoadQuotedPost = false
    @AppStorage("lastSelectedLocale") private var lastSelectedLocale: String = {
        Locale.current.language.languageCode?.identifier ?? "en"
    }()

    private var htmlContent: String {
        let document = Document(parsing: content)
        let rawHTML = HTMLFormatter.format(document)
        return HTMLStyles.wrapHTML(rawHTML, css: HTMLStyles.composePreviewCSS)
    }

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
                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                Text(NSLocalizedString("compose.placeholder", comment: "Compose text placeholder"))
                                    .font(fontSettings.font(for: .body))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $content)
                                .font(fontSettings.font(for: .body))
                                .opacity(content.isEmpty ? 0.25 : 1)
                                .onChange(of: content) { _, newValue in
                                    detectAndUpdateLanguage(from: newValue)
                                }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: showPreview)
                .animation(.easeInOut(duration: 0.25), value: isLoadingPreview)

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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    }
                    label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(NSLocalizedString("compose.cancel", comment: "Cancel button"))
                    .disabled(isPosting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("compose.post", comment: "Post button")) {
                        Task {
                            await post()
                        }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
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
        }
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

    private func post() async {
        isPosting = true
        defer { isPosting = false }

        do {
            let response = try await apolloClient.perform(
                mutation: HackersPub.CreateNoteMutation(
                    content: content,
                    language: lastSelectedLocale,
                    visibility: visibility,
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
