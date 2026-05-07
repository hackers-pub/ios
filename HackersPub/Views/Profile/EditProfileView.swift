import Apollo
import ApolloAPI
import Kingfisher
import PhotosUI
import SwiftUI

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
    @State private var isSaving = false
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?

    init(account: HackersPub.ViewerQuery.Data.Viewer, onSaved: @escaping () -> Void = {}) {
        self.account = account
        self.onSaved = onSaved
        _name = State(initialValue: account.name)
        _bio = State(initialValue: account.bio)
        _links = State(initialValue: account.links.map { EditableProfileLink(name: $0.name, url: $0.url) })
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
                    .disabled(isSaving || isLoadingPhoto)

                    if selectedAvatarData != nil {
                        Button(role: .destructive) {
                            selectedPhoto = nil
                            selectedAvatarData = nil
                            selectedAvatarImage = nil
                        } label: {
                            Text(NSLocalizedString("profile.edit.avatar.discard", comment: "Discard selected avatar button"))
                        }
                        .disabled(isSaving)
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
                .disabled(isSaving)

                TextField(
                    NSLocalizedString("profile.edit.bio", comment: "Bio field"),
                    text: $bio,
                    axis: .vertical
                )
                .lineLimit(4...10)
                .disabled(isSaving)
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
                        .disabled(isSaving)

                        TextField(
                            NSLocalizedString("profile.edit.link.url", comment: "Profile link URL field"),
                            text: $link.url
                        )
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .disabled(isSaving)

                        Button(role: .destructive) {
                            links.removeAll { $0.id == link.id }
                        } label: {
                            Label(NSLocalizedString("profile.edit.link.remove", comment: "Remove profile link button"), systemImage: "minus.circle")
                        }
                        .disabled(isSaving)
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    links.append(EditableProfileLink())
                } label: {
                    Label(NSLocalizedString("profile.edit.link.add", comment: "Add profile link button"), systemImage: "plus.circle")
                }
                .disabled(isSaving)
            } header: {
                Text(NSLocalizedString("profile.edit.links", comment: "Profile links section header"))
            }
        }
        .navigationTitle(NSLocalizedString("profile.edit.title", comment: "Edit profile navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let selectedAvatarImage {
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
        !isSaving &&
        !isLoadingPhoto &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        normalizedLinks != nil
    }

    private var normalizedLinks: [EditableProfileLink]? {
        var normalized: [EditableProfileLink] = []
        for link in links {
            let name = link.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = link.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty && url.isEmpty {
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

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                throw MediumUploadError.invalidImage
            }
            selectedAvatarData = data
            selectedAvatarImage = image
        } catch {
            selectedPhoto = nil
            selectedAvatarData = nil
            selectedAvatarImage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let normalizedLinks else {
            errorMessage = NSLocalizedString("profile.edit.link.error.incomplete", comment: "Incomplete profile link error")
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let avatarMediumId: GraphQLNullable<HackersPub.UUID>
            if let selectedAvatarData {
                let uploaded = try await MediumUploadService.shared.uploadImageData(selectedAvatarData)
                avatarMediumId = .some(uploaded.id)
            } else if let existingAvatarMediumId = account.avatarMediumId {
                avatarMediumId = .some(existingAvatarMediumId)
            } else {
                avatarMediumId = .none
            }

            _ = try await apolloClient.perform(
                mutation: HackersPub.UpdateAccountMutation(
                    id: account.id,
                    name: .some(trimmedName),
                    bio: .some(bio.trimmingCharacters(in: .whitespacesAndNewlines)),
                    avatarMediumId: avatarMediumId,
                    links: .some(normalizedLinks.map { HackersPub.AccountLinkInput(name: $0.name, url: $0.url) })
                )
            )
            await authManager.fetchViewer()
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EditableProfileLink: Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String

    init(id: UUID = UUID(), name: String = "", url: String = "") {
        self.id = id
        self.name = name
        self.url = url
    }
}
