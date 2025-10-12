import SwiftUI
@preconcurrency import Apollo
import Markdown
import NaturalLanguage

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var visibility: GraphQLEnum<HackersPub.PostVisibility> = .case(.public)
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showPreview = false
    @AppStorage("lastSelectedLocale") private var lastSelectedLocale: String = {
        Locale.current.language.languageCode?.identifier ?? "en"
    }()

    private var htmlContent: String {
        let document = Document(parsing: content)
        let rawHTML = HTMLFormatter.format(document)
        return HTMLStyles.wrapHTML(rawHTML, css: HTMLStyles.composePreviewCSS)
    }

    let replyToPostId: String?
    let replyToActor: String?

    init(replyToPostId: String? = nil, replyToActor: String? = nil) {
        self.replyToPostId = replyToPostId
        self.replyToActor = replyToActor
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

                // Editor/Preview toggle
                Picker(NSLocalizedString("compose.mode.edit", comment: "Mode picker"), selection: $showPreview) {
                    Text(NSLocalizedString("compose.mode.edit", comment: "Edit mode")).tag(false)
                    Text(NSLocalizedString("compose.mode.preview", comment: "Preview mode")).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Text editor or preview
                if showPreview {
                    MarkdownPreviewView(html: htmlContent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text(NSLocalizedString("compose.placeholder", comment: "Compose text placeholder"))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $content)
                            .font(.body)
                            .opacity(content.isEmpty ? 0.25 : 1)
                            .onChange(of: content) { _, newValue in
                                detectAndUpdateLanguage(from: newValue)
                            }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("compose.cancel", comment: "Cancel button")) {
                        dismiss()
                    }
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

    private func post() async {
        isPosting = true
        defer { isPosting = false }

        do {
            let response = try await apolloClient.perform(
                mutation: HackersPub.CreateNoteMutation(
                    content: content,
                    language: lastSelectedLocale,
                    visibility: visibility,
                    replyTargetId: replyToPostId.map { .some($0) } ?? nil
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
