import SwiftUI
@preconcurrency import Apollo
import Markdown

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var visibility: GraphQLEnum<HackersPub.PostVisibility> = .case(.public)
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showPreview = false
    @AppStorage("lastSelectedLocale") private var lastSelectedLocale: String = "en"

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
                        Text("Replying to @\(replyToActor)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        Spacer()
                    }
                }

                // Editor/Preview toggle
                Picker("Mode", selection: $showPreview) {
                    Text("Edit").tag(false)
                    Text("Preview").tag(true)
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
                            Text("What are you thinking?")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $content)
                            .font(.body)
                            .opacity(content.isEmpty ? 0.25 : 1)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                // Settings
                VStack(spacing: 12) {
                    // Visibility picker
                    Picker("Visibility", selection: $visibility) {
                        Text("Public").tag(GraphQLEnum<HackersPub.PostVisibility>.case(.public))
                        Text("Unlisted").tag(GraphQLEnum<HackersPub.PostVisibility>.case(.unlisted))
                        Text("Followers").tag(GraphQLEnum<HackersPub.PostVisibility>.case(.followers))
                    }
                    .pickerStyle(.segmented)

                    // Language picker
                    Picker("Language", selection: $lastSelectedLocale) {
                        ForEach(availableLocales, id: \.self) { locale in
                            Text(localeDisplayName(for: locale)).tag(locale)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding()
            }
            .navigationTitle(replyToPostId != nil ? "Reply" : "New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isPosting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            await post()
                        }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
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
                errorMessage = "Invalid input: \(invalidInput.inputPath)"
            } else if response.data?.createNote.asNotAuthenticatedError != nil {
                errorMessage = "You must be signed in to post"
            } else {
                errorMessage = "Failed to create post"
            }
        } catch {
            print("Error creating note: \(error)")
            errorMessage = "Failed to create post: \(error.localizedDescription)"
        }
    }
}
