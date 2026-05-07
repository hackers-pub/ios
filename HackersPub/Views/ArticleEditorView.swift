import Markdown
import NaturalLanguage
import PhotosUI
import SwiftUI
import UIKit
@preconcurrency import Apollo

struct ArticleEditSeed: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let tags: [String]
    let sourceArticleId: String?
    let language: String?
    let allowLlmTranslation: Bool?
}

struct ArticleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let draftId: String?
    let seed: ArticleEditSeed?
    let onComplete: () -> Void

    @State private var title = ""
    @State private var content = ""
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var savedDraftId: String?
    @State private var savedDraftUUID: String?
    @State private var slug = ""
    @State private var language = Locale.current.language.languageCode?.identifier ?? "en"
    @State private var didSelectLanguageManually = false
    @State private var allowLlmTranslation = true
    @State private var showPublishOptions = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isPublishing = false
    @State private var isLoadingPhotoAttachments = false
    @State private var isUploadingPhotoAttachments = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoAttachments: [ArticlePhotoAttachment] = []
    @State private var editingPhotoAttachment: ArticlePhotoAttachmentEditorTarget?
    @State private var publishedArticleMedia: [HackersPub.UpdateArticleMediumInput] = []
    @State private var showPreview = false
    @State private var errorMessage: String?

    init(draftId: String? = nil, seed: ArticleEditSeed? = nil, onComplete: @escaping () -> Void = {}) {
        self.draftId = draftId
        self.seed = seed
        self.onComplete = onComplete
    }

    private var htmlContent: String {
        HTMLStyles.wrapHTML(
            HTMLFormatter.format(Document(parsing: content)),
            css: HTMLStyles.composePreviewCSS
        )
    }

    private var hasTitleForPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving && !isPublishing
            && !isUploadingPhotoAttachments
    }

    private var canSave: Bool {
        hasTitleForPublish
    }

    private var isEditingPublishedArticle: Bool {
        seed?.sourceArticleId != nil
    }

    private var selectedLanguage: Binding<String> {
        Binding(
            get: { language },
            set: { newValue in
                language = newValue
                didSelectLanguageManually = true
            }
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

    private var navigationTitle: String {
        if seed?.sourceArticleId != nil {
            return NSLocalizedString("article.edit", comment: "Edit article")
        }
        if draftId != nil {
            return NSLocalizedString("article.editDraft", comment: "Edit draft")
        }
        return NSLocalizedString("article.new", comment: "New article")
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if showPublishOptions {
                    PublishArticleOptionsView(
                        slug: $slug,
                        language: selectedLanguage,
                        allowLlmTranslation: $allowLlmTranslation,
                        availableLocales: availableLocales,
                        showsSlug: !isEditingPublishedArticle,
                        actionTitle: isEditingPublishedArticle
                            ? NSLocalizedString("article.update", comment: "Update article")
                            : NSLocalizedString("article.publish", comment: "Publish"),
                        isPublishing: isPublishing,
                        onCancel: {
                            withAnimation(.snappy(duration: 0.28)) {
                                showPublishOptions = false
                            }
                        },
                        onPublish: {
                            Task {
                                await publish()
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else {
                    VStack(spacing: 0) {
                        Picker("", selection: $showPreview) {
                            Text(NSLocalizedString("compose.mode.edit", comment: "Edit mode")).tag(false)
                            Text(NSLocalizedString("compose.mode.preview", comment: "Preview mode")).tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        if showPreview {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    if !title.isEmpty {
                                        Text(title)
                                            .font(.largeTitle.bold())
                                    }
                                    PostContentDetailView(html: htmlContent, media: [])
                                }
                                .padding()
                            }
                            .scrollDismissesKeyboard(.interactively)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 24) {
                                    ArticleMetadataEditor(
                                        title: $title,
                                        tags: $tags,
                                        tagInput: $tagInput,
                                        onTitleChange: handleTitleChange
                                    )

                                    ArticlePhotoAttachmentEditor(
                                        attachments: $photoAttachments,
                                        isLoading: isLoadingPhotoAttachments,
                                        isUploading: isUploadingPhotoAttachments,
                                        selectedItems: $selectedPhotoItems,
                                        onRemove: { id in
                                            photoAttachments.removeAll { $0.id == id }
                                        },
                                        onEdit: { id in
                                            editingPhotoAttachment = ArticlePhotoAttachmentEditorTarget(id: id)
                                        },
                                        onUpload: {
                                            Task {
                                                await uploadPhotoAttachments()
                                            }
                                        }
                                    )

                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(NSLocalizedString("article.content", comment: "Article content"))
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 30)

                                        ArticleMarkdownTextEditor(
                                            text: $content,
                                            placeholder: NSLocalizedString("article.content.placeholder", comment: "Article content placeholder")
                                        )
                                        .onChange(of: content) { _, _ in
                                            detectLanguageFromCurrentDraft()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 32)
                            }
                            .scrollDismissesKeyboard(.interactively)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .background(Color(.systemGroupedBackground))
            .animation(.snappy(duration: 0.28), value: showPublishOptions)
            .navigationTitle(showPublishOptions ? publishOptionsTitle : navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if showPublishOptions {
                            withAnimation(.snappy(duration: 0.28)) {
                                showPublishOptions = false
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: showPublishOptions ? "chevron.left" : "xmark")
                    }
                    .accessibilityLabel(NSLocalizedString("common.cancel", comment: "Cancel"))
                }
                if !showPublishOptions {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if !isEditingPublishedArticle {
                            Button {
                                Task {
                                    await saveDraft()
                                }
                            } label: {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Image(systemName: "tray.and.arrow.down")
                                }
                            }
                            .accessibilityLabel(NSLocalizedString("article.saveDraft", comment: "Save draft"))
                            .disabled(!canSave)
                        }

                        Button {
                            detectLanguageFromCurrentDraft()
                            if isEditingPublishedArticle {
                                withAnimation(.snappy(duration: 0.28)) {
                                    showPublishOptions = true
                                }
                            } else if savedDraftId == nil {
                                Task {
                                    if await saveDraft() != nil {
                                        withAnimation(.snappy(duration: 0.28)) {
                                            showPublishOptions = true
                                        }
                                    }
                                }
                            } else {
                                withAnimation(.snappy(duration: 0.28)) {
                                    showPublishOptions = true
                                }
                            }
                        } label: {
                            Image(systemName: "paperplane")
                        }
                        .accessibilityLabel(
                            isEditingPublishedArticle
                                ? NSLocalizedString("article.update", comment: "Update article")
                                : NSLocalizedString("article.publish", comment: "Publish")
                        )
                        .disabled(!canSave)
                    }
                }
            }
            .task {
                await initialize()
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await loadPhotoAttachments(from: newItems)
                    selectedPhotoItems = []
                }
            }
            .sheet(item: $editingPhotoAttachment) { target in
                if let index = photoAttachments.firstIndex(where: { $0.id == target.id }) {
                    ArticlePhotoDetailsSheet(attachment: $photoAttachments[index])
                }
            }
            .alert(
                NSLocalizedString("compose.error.title", comment: "Error"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(NSLocalizedString("compose.error.ok", comment: "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var publishOptionsTitle: String {
        isEditingPublishedArticle
            ? NSLocalizedString("article.updateOptions", comment: "Update article options")
            : NSLocalizedString("article.publishOptions", comment: "Publish article options")
    }

    private func initialize() async {
        if let seed {
            title = seed.title
            content = seed.content
            tags = seed.tags
            savedDraftId = nil
            savedDraftUUID = nil
            slug = Self.generateSlug(seed.title)
            if let seedLanguage = seed.language, !seedLanguage.isEmpty {
                language = seedLanguage
                didSelectLanguageManually = true
            } else {
                detectLanguageFromCurrentDraft()
            }
            if let seedAllowLlmTranslation = seed.allowLlmTranslation {
                allowLlmTranslation = seedAllowLlmTranslation
            }
            return
        }

        guard let draftId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.ArticleDraftQuery(id: draftId), cachePolicy: .networkOnly)
            guard let draft = response.data?.articleDraft else { return }
            title = draft.title
            content = draft.content
            tags = draft.tags
            savedDraftId = draft.id
            savedDraftUUID = draft.uuid
            slug = Self.generateSlug(draft.title)
            detectLanguageFromCurrentDraft()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    private func saveDraft() async -> String? {
        guard hasTitleForPublish else { return savedDraftId }
        return await saveDraft(
            title: title,
            content: content,
            tags: commitPendingTags()
        )
    }

    @discardableResult
    private func saveDraft(title draftTitle: String, content draftContent: String, tags draftTags: [String]) async -> String? {
        isSaving = true
        defer { isSaving = false }

        do {
            let response = try await apolloClient.perform(
                mutation: HackersPub.SaveArticleDraftMutation(
                    title: draftTitle,
                    content: draftContent,
                    tags: draftTags,
                    id: savedDraftId.map(GraphQLNullable.some) ?? .none
                )
            )

            if let payload = response.data?.saveArticleDraft.asSaveArticleDraftPayload {
                savedDraftId = payload.draft.id
                savedDraftUUID = payload.draft.uuid
                return payload.draft.id
            }

            if let invalid = response.data?.saveArticleDraft.asInvalidInputError {
                errorMessage = "Invalid input: \(invalid.inputPath)"
            } else {
                errorMessage = NSLocalizedString("article.saveFailed", comment: "Article save failed")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return nil
    }

    @discardableResult
    private func ensureDraftForMedia() async -> String? {
        if let savedDraftUUID {
            return savedDraftUUID
        }
        let fallbackTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? NSLocalizedString("article.untitled", comment: "Untitled article")
            : title
        let fallbackContent = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? " "
            : content
        guard await saveDraft(
            title: fallbackTitle,
            content: fallbackContent,
            tags: ArticleTagNormalizer.merged(existing: tags, input: tagInput)
        ) != nil else {
            return nil
        }
        return savedDraftUUID
    }

    private func publish() async {
        guard !isPublishing else { return }
        if isEditingPublishedArticle {
            await updatePublishedArticle()
            return
        }
        let draftId = await saveDraft()
        guard let draftId else { return }

        isPublishing = true
        defer { isPublishing = false }

        do {
            let response = try await apolloClient.perform(
                mutation: HackersPub.PublishArticleDraftMutation(
                    id: draftId,
                    slug: slug,
                    language: language,
                    allowLlmTranslation: .some(allowLlmTranslation)
                )
            )

            if response.data?.publishArticleDraft.asPublishArticleDraftPayload?.article != nil {
                NotificationCenter.default.post(name: Notification.Name("RefreshTimeline"), object: nil)
                onComplete()
                dismiss()
            } else if let invalid = response.data?.publishArticleDraft.asInvalidInputError {
                errorMessage = "Invalid input: \(invalid.inputPath)"
            } else {
                errorMessage = NSLocalizedString("article.publishFailed", comment: "Article publish failed")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updatePublishedArticle() async {
        guard let articleId = seed?.sourceArticleId else { return }
        let updatedTags = commitPendingTags()
        isPublishing = true
        defer { isPublishing = false }

        do {
            let response = try await apolloClient.perform(
                mutation: HackersPub.UpdateArticleMutation(
                    articleId: articleId,
                    title: title,
                    content: content,
                    tags: updatedTags,
                    language: language,
                    allowLlmTranslation: allowLlmTranslation,
                    media: publishedArticleMedia.isEmpty ? .none : .some(publishedArticleMedia)
                )
            )

            if response.data?.updateArticle.asUpdateArticlePayload?.article != nil {
                NotificationCenter.default.post(name: Notification.Name("RefreshTimeline"), object: nil)
                onComplete()
                dismiss()
            } else if let invalid = response.data?.updateArticle.asInvalidInputError {
                errorMessage = invalid.inputPath == "language"
                    ? NSLocalizedString("article.updateLanguageFailed", comment: "Article language update failed")
                    : "Invalid input: \(invalid.inputPath)"
            } else {
                errorMessage = NSLocalizedString("article.updateFailed", comment: "Article update failed")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func commitPendingTags() -> [String] {
        let updatedTags = ArticleTagNormalizer.merged(existing: tags, input: tagInput)
        tags = updatedTags
        tagInput = ""
        return updatedTags
    }

    private func handleTitleChange(_ newValue: String) {
        slug = Self.generateSlug(newValue)
        detectLanguageFromCurrentDraft()
    }

    private func detectLanguageFromCurrentDraft() {
        guard !didSelectLanguageManually else { return }
        let text = [title, content]
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let languageCode = recognizer.dominantLanguage?.rawValue else { return }
        if availableLocales.contains(languageCode) {
            language = languageCode
        } else {
            let baseLanguage = String(languageCode.prefix(2))
            if availableLocales.contains(baseLanguage) {
                language = baseLanguage
            }
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
                    throw MediumUploadError.invalidImage
                }
                photoAttachments.append(ArticlePhotoAttachment(data: data, image: image))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func uploadPhotoAttachments() async {
        guard !photoAttachments.isEmpty, !isUploadingPhotoAttachments else { return }

        let draftId: String?
        if isEditingPublishedArticle {
            draftId = nil
        } else {
            draftId = await ensureDraftForMedia()
            guard draftId != nil else { return }
        }

        isUploadingPhotoAttachments = true
        defer { isUploadingPhotoAttachments = false }

        do {
            var uploadedAttachmentIDs: Set<ArticlePhotoAttachment.ID> = []
            for attachment in photoAttachments {
                let uploaded = try await MediumUploadService.shared.uploadImageData(attachment.data)
                let key = uploaded.id
                let attachedKey: String
                if let draftId {
                    let response = try await apolloClient.perform(
                        mutation: HackersPub.AttachArticleDraftMediumMutation(
                            draftId: draftId,
                            mediumId: uploaded.id,
                            key: .some(key)
                        )
                    )
                    if let error = response.errors?.first {
                        throw MediumUploadError.server(error.localizedDescription)
                    }
                    if let payload = response.data?.attachArticleDraftMedium.asAttachArticleDraftMediumPayload {
                        _ = payload
                        attachedKey = key
                    } else if let invalid = response.data?.attachArticleDraftMedium.asInvalidInputError {
                        throw MediumUploadError.invalidInput(invalid.inputPath)
                    } else if response.data?.attachArticleDraftMedium.asNotAuthenticatedError != nil {
                        throw MediumUploadError.notAuthenticated
                    } else {
                        throw MediumUploadError.missingPayload("attach")
                    }
                } else {
                    publishedArticleMedia.append(
                        HackersPub.UpdateArticleMediumInput(
                            key: .some(key),
                            mediumId: uploaded.id
                        )
                    )
                    attachedKey = key
                }

                insertMarkdownImage(alt: attachment.alt, key: attachedKey)
                uploadedAttachmentIDs.insert(attachment.id)
            }
            photoAttachments.removeAll { uploadedAttachmentIDs.contains($0.id) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func insertMarkdownImage(alt: String, key: String) {
        let escapedAlt = alt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "]", with: "\\]")
        let imageMarkdown = "![\(escapedAlt)](hp-medium:\(key))"
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content = imageMarkdown
        } else {
            content += "\n\n\(imageMarkdown)"
        }
        detectLanguageFromCurrentDraft()
    }

    static func generateSlug(_ title: String) -> String {
        title
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}\\s-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .prefix(128)
            .description
    }
}

private struct ArticleMetadataEditor: View {
    @Binding var title: String
    @Binding var tags: [String]
    @Binding var tagInput: String
    let onTitleChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(NSLocalizedString("article.title", comment: "Article title"), text: $title)
                .font(.title3)
                .textInputAutocapitalization(.sentences)
                .onChange(of: title) { _, newValue in
                    onTitleChange(newValue)
                }

            Divider()

            ArticleTagEditor(tags: $tags, input: $tagInput)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct ArticlePhotoAttachment: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let image: UIImage
    var alt = ""
}

private struct ArticlePhotoAttachmentEditorTarget: Identifiable {
    let id: ArticlePhotoAttachment.ID
}

private struct ArticlePhotoAttachmentEditor: View {
    @Binding var attachments: [ArticlePhotoAttachment]
    let isLoading: Bool
    let isUploading: Bool
    @Binding var selectedItems: [PhotosPickerItem]
    let onRemove: (ArticlePhotoAttachment.ID) -> Void
    let onEdit: (ArticlePhotoAttachment.ID) -> Void
    let onUpload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(NSLocalizedString("article.photos.title", comment: "Article photos section title"), systemImage: "photo")
                    .font(.headline)
                Spacer()
                if isLoading || isUploading {
                    ProgressView()
                        .controlSize(.small)
                }
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Image(systemName: "photo.badge.plus")
                }
                .accessibilityLabel(NSLocalizedString("article.photos.add", comment: "Add article photos button"))
                .disabled(isLoading || isUploading)
            }

            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach($attachments) { $attachment in
                            ArticlePendingPhotoView(
                                attachment: $attachment,
                                onEdit: {
                                    onEdit(attachment.id)
                                },
                                onDelete: {
                                    onRemove(attachment.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    onUpload()
                } label: {
                    if isUploading {
                        ProgressView()
                    } else {
                        Label(NSLocalizedString("article.photos.insert", comment: "Insert uploaded article photos button"), systemImage: "text.badge.plus")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || isUploading)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct ArticlePendingPhotoView: View {
    @Binding var attachment: ArticlePhotoAttachment
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: attachment.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 156, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ArticlePhotoDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var attachment: ArticlePhotoAttachment

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

private struct ArticleMarkdownTextEditor: View {
    @Binding var text: String
    let placeholder: String
    @State private var measuredHeight: CGFloat = 380

    var body: some View {
        AutoSizingMarkdownTextView(
            text: $text,
            measuredHeight: $measuredHeight,
            placeholder: placeholder
        )
        .frame(minHeight: max(380, measuredHeight))
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct AutoSizingMarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    let placeholder: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.installPlaceholder(in: textView)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.updatePlaceholder(
            placeholder,
            font: uiView.font,
            isHidden: !text.isEmpty
        )
        updateHeight(uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, measuredHeight: $measuredHeight)
    }

    private func updateHeight(_ textView: UITextView) {
        let width = textView.bounds.width > 0 ? textView.bounds.width : 320
        let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = max(380, ceil(size.height))
        guard abs(measuredHeight - height) > 1 else { return }
        DispatchQueue.main.async {
            measuredHeight = height
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var measuredHeight: CGFloat
        private let placeholderLabel = UILabel()

        init(text: Binding<String>, measuredHeight: Binding<CGFloat>) {
            _text = text
            _measuredHeight = measuredHeight
        }

        func installPlaceholder(in textView: UITextView) {
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            placeholderLabel.textColor = .placeholderText
            placeholderLabel.numberOfLines = 0
            placeholderLabel.isUserInteractionEnabled = false
            textView.addSubview(placeholderLabel)
            NSLayoutConstraint.activate([
                placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
                placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
                placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor)
            ])
        }

        func updatePlaceholder(_ text: String, font: UIFont?, isHidden: Bool) {
            placeholderLabel.text = text
            placeholderLabel.font = font
            placeholderLabel.isHidden = isHidden
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            placeholderLabel.isHidden = !textView.text.isEmpty
            let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
            let height = max(380, ceil(size.height))
            if abs(measuredHeight - height) > 1 {
                measuredHeight = height
            }
        }
    }
}

private struct PublishArticleOptionsView: View {
    @Binding var slug: String
    @Binding var language: String
    @Binding var allowLlmTranslation: Bool
    let availableLocales: [String]
    let showsSlug: Bool
    let actionTitle: String
    let isPublishing: Bool
    let onCancel: () -> Void
    let onPublish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("article.publishOptions.title", comment: "Publish options title"))
                            .font(.title2.bold())
                        Text(NSLocalizedString("article.publishOptions.message", comment: "Publish options message"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        if showsSlug {
                            ArticlePublishField(
                                title: NSLocalizedString("article.slug", comment: "Article slug"),
                                subtitle: NSLocalizedString("article.slugHelp", comment: "Article slug help")
                            ) {
                                TextField(NSLocalizedString("article.slug", comment: "Article slug"), text: $slug)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.plain)
                                    .font(.body)
                            }

                            Divider().padding(.leading, 16)
                        }

                        ArticlePublishField(
                            title: NSLocalizedString("article.language", comment: "Article language"),
                            subtitle: NSLocalizedString("article.languageHelp", comment: "Article language help")
                        ) {
                            Picker(NSLocalizedString("article.language", comment: "Article language"), selection: $language) {
                                ForEach(availableLocales, id: \.self) { locale in
                                    Text(ArticleLocale.displayName(for: locale)).tag(locale)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        Divider().padding(.leading, 16)

                        Toggle(isOn: $allowLlmTranslation) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(NSLocalizedString("article.allowLlmTranslation", comment: "Allow LLM translation"))
                                    .font(.body)
                                Text(NSLocalizedString("article.allowLlmTranslationHelp", comment: "Allow LLM translation help"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding()
            }

            Divider()
            HStack(spacing: 12) {
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Button(action: onPublish) {
                    if isPublishing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(actionTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled((showsSlug && slug.nilIfBlank == nil) || isPublishing)
            }
            .padding()
            .background(.regularMaterial)
        }
    }
}

private struct ArticlePublishField<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)
                content
            }
        }
        .padding(16)
    }
}

private enum ArticleLocale {
    static func displayName(for localeCode: String) -> String {
        let locale = Locale(identifier: localeCode)
        if let displayName = locale.localizedString(forIdentifier: localeCode) {
            return "\(displayName) (\(localeCode))"
        }
        return localeCode
    }
}

private struct ArticleTagEditor: View {
    @Binding var tags: [String]
    @Binding var input: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TagWrappingLayout(spacing: 8, lineSpacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .lineLimit(1)
                        Button {
                            remove(tag)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(format: NSLocalizedString("article.tag.remove", comment: "Remove article tag"), tag))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                }

                TextField(NSLocalizedString("article.tags", comment: "Article tags"), text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .frame(minWidth: 120)
                    .onSubmit(commitInput)
                    .onChange(of: input) { _, newValue in
                        if containsTagSeparator(newValue) {
                            commitInput()
                        }
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func containsTagSeparator(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.whitespacesAndNewlines.contains($0) || $0 == "," }
    }

    private func commitInput() {
        tags = ArticleTagNormalizer.merged(existing: tags, input: input)
        input = ""
    }

    private func remove(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

private enum ArticleTagNormalizer {
    static func merged(existing tags: [String], input: String) -> [String] {
        normalized(tags + normalizedInput(input))
    }

    private static func normalizedInput(_ input: String) -> [String] {
        input
            .split { character in
                character == "," || character.isWhitespace
            }
            .map { String($0) }
    }

    private static func normalized(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let tag = value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard !tag.isEmpty else { return nil }
            let key = tag.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return tag
        }
    }
}

private struct TagWrappingLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let rows = rows(for: subviews, maxWidth: proposal.width ?? 320)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [(width: CGFloat, height: CGFloat)] {
        var rows: [(width: CGFloat, height: CGFloat)] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = rowWidth == 0 ? size.width : rowWidth + spacing + size.width
            if rowWidth > 0, nextWidth > maxWidth {
                rows.append((rowWidth, rowHeight))
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = nextWidth
                rowHeight = max(rowHeight, size.height)
            }
        }

        if rowWidth > 0 {
            rows.append((rowWidth, rowHeight))
        }
        return rows
    }
}
