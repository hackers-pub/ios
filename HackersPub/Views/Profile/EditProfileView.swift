import Apollo
import ApolloAPI
import Foundation
import Kingfisher
import PhotosUI
import SwiftUI

// swiftlint:disable file_length

enum ProfileUpdateResponseGate {
    static func shouldDismiss(hasResponseErrors: Bool, hasAccount: Bool) -> Bool {
        !hasResponseErrors && hasAccount
    }
}

enum ProfileAvatarMutationPlan: Equatable {
    case omit
    case upload(Data)
    case clear
}

enum ProfileAvatarIntent: Equatable {
    case unchanged
    case replacement(Data)
    case remove

    var mutationPlan: ProfileAvatarMutationPlan {
        switch self {
        case .unchanged:
            .omit
        case let .replacement(data):
            .upload(data)
        case .remove:
            .clear
        }
    }

    var requiresUpload: Bool {
        if case .replacement = self {
            return true
        }
        return false
    }

    mutating func restore() {
        self = .unchanged
    }
}

struct ProfileEditSnapshot: Equatable {
    let name: String
    let bio: String
    let links: [EditableProfileLink]
    let avatarIntent: ProfileAvatarIntent
}

enum ProfileSaveMutationResponse: Equatable {
    case saved
    case failed(String)
}

@MainActor
final class ProfileSaveCoordinator {
    private let gate = RevisionedSingleFlightCoordinator<ProfileEditSnapshot>()

    func save(
        snapshot: ProfileEditSnapshot,
        currentSnapshot: @escaping @MainActor () -> ProfileEditSnapshot,
        operation: @escaping @MainActor () async -> ProfileSaveMutationResponse
    ) async -> RevisionedOperationResult<ProfileSaveMutationResponse> {
        await gate.run(revision: snapshot, currentRevision: currentSnapshot) { _ in
            await operation()
        }
    }
}

enum ProfilePhotoLoadAttempt: Equatable {
    case loaded(Data)
    case failed(String)
}

struct ProfilePhotoLoadToken: Equatable {
    let itemID: String
    let generation: Int
}

enum ProfilePhotoLoadResolution: Equatable {
    case current(ProfilePhotoLoadToken, ProfilePhotoLoadAttempt)
    case stale
}

@MainActor
final class ProfilePhotoLoadCoordinator {
    private var generation = 0
    private var activeItemID: String?
    private var loadTask: Task<ProfilePhotoLoadAttempt, Never>?

    func load(
        itemID: String,
        operation: @escaping @MainActor () async -> ProfilePhotoLoadAttempt
    ) async -> ProfilePhotoLoadResolution {
        generation &+= 1
        let operationGeneration = generation
        let token = ProfilePhotoLoadToken(itemID: itemID, generation: operationGeneration)
        activeItemID = itemID
        loadTask?.cancel()

        let task = Task { await operation() }
        loadTask = task
        let attempt = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }

        guard operationGeneration == generation,
              activeItemID == itemID
        else {
            return .stale
        }
        loadTask = nil
        guard !Task.isCancelled else {
            generation &+= 1
            activeItemID = nil
            return .stale
        }
        return .current(token, attempt)
    }

    @discardableResult
    func applyIfCurrent(
        _ resolution: ProfilePhotoLoadResolution,
        apply: @MainActor (ProfilePhotoLoadAttempt) -> Void
    ) -> Bool {
        guard case let .current(token, attempt) = resolution,
              token.generation == generation,
              token.itemID == activeItemID
        else {
            return false
        }
        apply(attempt)
        return true
    }

    func invalidate() {
        generation &+= 1
        activeItemID = nil
        loadTask?.cancel()
        loadTask = nil
    }
}

enum ProfileEditCloseRoute: Equatable {
    case dismiss
    case confirmDiscard
    case blocked

    static func resolve(hasChanges: Bool, isBusy: Bool) -> Self {
        if isBusy {
            return .blocked
        }
        return hasChanges ? .confirmDiscard : .dismiss
    }
}

// swiftlint:disable:next type_body_length
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager

    let account: HackersPub.ViewerQuery.Data.Viewer
    let onSaved: () -> Void

    @State private var name: String
    @State private var bio: String
    @State private var links: [EditableProfileLink]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedAvatarData: Data?
    @State private var selectedAvatarImage: UIImage?
    @State private var avatarIntent: ProfileAvatarIntent = .unchanged
    @State private var initialSnapshot: ProfileEditSnapshot
    @State private var isSaving = false
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?
    @State private var showDiscardConfirmation = false
    @State private var saveCoordinator = ProfileSaveCoordinator()
    @State private var photoLoadCoordinator = ProfilePhotoLoadCoordinator()

    init(account: HackersPub.ViewerQuery.Data.Viewer, onSaved: @escaping () -> Void = {}) {
        self.account = account
        self.onSaved = onSaved
        let initialLinks = account.links.map { EditableProfileLink(name: $0.name, url: $0.url) }
        _name = State(initialValue: account.name)
        _bio = State(initialValue: account.bio)
        _links = State(initialValue: initialLinks)
        _initialSnapshot = State(initialValue: ProfileEditSnapshot(
            name: account.name,
            bio: account.bio,
            links: initialLinks,
            avatarIntent: .unchanged
        ))
    }

    private var isBusy: Bool {
        isSaving || isLoadingPhoto
    }

    private var currentSnapshot: ProfileEditSnapshot {
        ProfileEditSnapshot(
            name: name,
            bio: bio,
            links: links,
            avatarIntent: avatarIntent
        )
    }

    private var hasChanges: Bool {
        initialSnapshot != currentSnapshot
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    avatarPreview

                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            NSLocalizedString("profile.edit.avatar.choose", comment: "Choose avatar button"),
                            systemImage: "photo"
                        )
                    }
                    .disabled(isBusy)

                    if avatarIntent == .remove {
                        Button {
                            avatarIntent.restore()
                        } label: {
                            Label(
                                NSLocalizedString("profile.edit.avatar.restore", comment: "Restore avatar button"),
                                systemImage: "arrow.uturn.backward"
                            )
                        }
                        .disabled(isBusy)
                    } else {
                        if selectedAvatarData != nil {
                            Button(role: .destructive) {
                                discardSelectedAvatar()
                            } label: {
                                Text(
                                    NSLocalizedString(
                                        "profile.edit.avatar.discard",
                                        comment: "Discard selected avatar button"
                                    )
                                )
                            }
                            .disabled(isBusy)
                        }

                        if account.avatarMediumId != nil {
                            Button(role: .destructive) {
                                removeAvatar()
                            } label: {
                                Label(
                                    NSLocalizedString("profile.edit.avatar.remove", comment: "Remove avatar button"),
                                    systemImage: "trash"
                                )
                            }
                            .disabled(isBusy)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } header: {
                Text(NSLocalizedString("profile.edit.avatar", comment: "Avatar section header"))
            }

            Section {
                TextField(
                    NSLocalizedString("profile.edit.name", comment: "Display name field"),
                    text: $name
                )
                .textInputAutocapitalization(.words)
                .disabled(isBusy)

                TextField(
                    NSLocalizedString("profile.edit.bio", comment: "Bio field"),
                    text: $bio,
                    axis: .vertical
                )
                .lineLimit(4 ... 10)
                .disabled(isBusy)
            } header: {
                Text(NSLocalizedString("profile.edit.details", comment: "Profile details section header"))
            }

            Section {
                ForEach($links) { $link in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(
                            NSLocalizedString("profile.edit.link.name", comment: "Profile link name field"),
                            text: $link.name
                        )
                        .textInputAutocapitalization(.words)
                        .disabled(isBusy)

                        TextField(
                            NSLocalizedString("profile.edit.link.url", comment: "Profile link URL field"),
                            text: $link.url
                        )
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .disabled(isBusy)

                        Button(role: .destructive) {
                            links.removeAll { $0.id == link.id }
                        } label: {
                            Label(NSLocalizedString("profile.edit.link.remove", comment: "Remove profile link button"), systemImage: "minus.circle")
                        }
                        .disabled(isBusy)
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    links.append(EditableProfileLink())
                } label: {
                    Label(NSLocalizedString("profile.edit.link.add", comment: "Add profile link button"), systemImage: "plus.circle")
                }
                .disabled(isBusy)
            } header: {
                Text(NSLocalizedString("profile.edit.links", comment: "Profile links section header"))
            }
        }
        .navigationTitle(NSLocalizedString("profile.edit.title", comment: "Edit profile navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                    requestClose()
                }
                .disabled(isBusy)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(NSLocalizedString("profile.edit.save", comment: "Save profile button"))
                    }
                }
                .disabled(!canSave)
            }
        }
        .overlay {
            if isLoadingPhoto {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                await loadPhoto(item)
            }
        }
        .alert(NSLocalizedString("profile.edit.error.title", comment: "Edit profile error title"), isPresented: errorBinding) {
            Button(NSLocalizedString("compose.error.ok", comment: "OK button"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            NSLocalizedString("profile.edit.discard.title", comment: "Discard profile changes title"),
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                NSLocalizedString("profile.edit.discard.action", comment: "Discard profile changes"),
                role: .destructive
            ) {
                dismiss()
            }
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("profile.edit.discard.message", comment: "Unsaved profile changes message"))
        }
        .interactiveDismissDisabled(hasChanges || isBusy)
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if avatarIntent == .remove {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 96, height: 96)
                .overlay {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(
                    NSLocalizedString(
                        "profile.edit.avatar.removed",
                        comment: "Avatar removed placeholder"
                    )
                )
        } else if let selectedAvatarImage {
            Image(uiImage: selectedAvatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
        } else {
            KFImage(URL(string: account.avatarUrl))
                .placeholder {
                    Color.gray.opacity(0.2)
                }
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
        }
    }

    private var canSave: Bool {
        !isBusy &&
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            normalizedLinks != nil
    }

    private var normalizedLinks: [EditableProfileLink]? {
        var normalized: [EditableProfileLink] = []
        for link in links {
            let name = link.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = link.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty, url.isEmpty {
                continue
            }
            guard !name.isEmpty, !url.isEmpty else {
                return nil
            }
            normalized.append(EditableProfileLink(id: link.id, name: name, url: url))
        }
        return normalized
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func requestClose() {
        switch ProfileEditCloseRoute.resolve(hasChanges: hasChanges, isBusy: isBusy) {
        case .dismiss:
            dismiss()
        case .confirmDiscard:
            showDiscardConfirmation = true
        case .blocked:
            break
        }
    }

    private func discardSelectedAvatar() {
        photoLoadCoordinator.invalidate()
        isLoadingPhoto = false
        selectedPhoto = nil
        selectedAvatarData = nil
        selectedAvatarImage = nil
        avatarIntent.restore()
    }

    private func removeAvatar() {
        photoLoadCoordinator.invalidate()
        isLoadingPhoto = false
        selectedPhoto = nil
        selectedAvatarData = nil
        selectedAvatarImage = nil
        avatarIntent = .remove
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            photoLoadCoordinator.invalidate()
            isLoadingPhoto = false
            return
        }

        isLoadingPhoto = true
        let itemID = item.itemIdentifier ?? UUID().uuidString
        let resolution = await photoLoadCoordinator.load(itemID: itemID) {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      UIImage(data: data) != nil
                else {
                    throw MediumUploadError.invalidImage
                }
                return .loaded(data)
            } catch {
                return .failed(error.localizedDescription)
            }
        }

        photoLoadCoordinator.applyIfCurrent(resolution) { attempt in
            isLoadingPhoto = false
            switch attempt {
            case let .loaded(data):
                selectedAvatarData = data
                selectedAvatarImage = UIImage(data: data)
                avatarIntent = .replacement(data)
            case let .failed(message):
                selectedPhoto = nil
                selectedAvatarData = nil
                selectedAvatarImage = nil
                avatarIntent = .unchanged
                errorMessage = message
            }
        }
    }

    private func save() async {
        guard !isSaving else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let normalizedLinks else {
            errorMessage = NSLocalizedString("profile.edit.link.error.incomplete", comment: "Incomplete profile link error")
            return
        }

        let snapshot = currentSnapshot
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarMutationPlan = snapshot.avatarIntent.mutationPlan

        isSaving = true
        defer { isSaving = false }

        let result = await saveCoordinator.save(
            snapshot: snapshot,
            currentSnapshot: { currentSnapshot },
            operation: {
                await performSave(
                    name: trimmedName,
                    bio: trimmedBio,
                    links: normalizedLinks,
                    avatarMutationPlan: avatarMutationPlan
                )
            }
        )

        switch result {
        case .blocked:
            return
        case .stale:
            errorMessage = NSLocalizedString(
                "profile.edit.error.changedDuringSave",
                comment: "Profile changed during save error"
            )
        case let .current(.failed(message)):
            errorMessage = message
        case .current(.saved):
            await authManager.fetchViewer()
            onSaved()
            dismiss()
        }
    }

    private func performSave(
        name: String,
        bio: String,
        links: [EditableProfileLink],
        avatarMutationPlan: ProfileAvatarMutationPlan
    ) async -> ProfileSaveMutationResponse {
        do {
            let avatarMediumId: GraphQLNullable<HackersPub.UUID>
            switch avatarMutationPlan {
            case .omit:
                avatarMediumId = .none
            case let .upload(data):
                let uploaded = try await MediumUploadService.shared.uploadImageData(data)
                avatarMediumId = .some(uploaded.id)
            case .clear:
                avatarMediumId = .null
            }

            let response = try await apolloClient.perform(
                mutation: HackersPub.UpdateAccountMutation(
                    id: account.id,
                    name: .some(name),
                    bio: .some(bio),
                    avatarMediumId: avatarMediumId,
                    links: .some(links.map { HackersPub.AccountLinkInput(name: $0.name, url: $0.url) })
                )
            )
            guard ProfileUpdateResponseGate.shouldDismiss(
                hasResponseErrors: response.errors?.isEmpty == false,
                hasAccount: response.data?.updateAccount.account != nil
            ) else {
                return .failed(
                    response.errors?.first?.localizedDescription
                        ?? NSLocalizedString(
                            "profile.edit.error.missingPayload",
                            comment: "Profile update response missing account"
                        )
                )
            }
            return .saved
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

struct EditableProfileLink: Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String

    init(id: UUID = UUID(), name: String = "", url: String = "") {
        self.id = id
        self.name = name
        self.url = url
    }
}

// swiftlint:enable file_length
