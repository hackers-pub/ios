import Foundation
import SwiftUI
import UIKit

struct PendingPhotoAttachment: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let image: UIImage
    var alt = ""
    var uploadedMediumID: String?
    var uploadedMediumNodeID: String?

    var requiresUpload: Bool {
        uploadedMediumID == nil
    }

    mutating func recordUploadedMedium(id: String, nodeID: String? = nil) {
        uploadedMediumID = id
        if let nodeID {
            uploadedMediumNodeID = nodeID
        }
    }
}

@MainActor
struct ComposePhotoAttachmentUploadAdapter {
    private let attachments: Binding<[PendingPhotoAttachment]>

    init(attachments: Binding<[PendingPhotoAttachment]>) {
        self.attachments = attachments
    }

    func upload(
        upload: (PendingPhotoAttachment) async throws -> String
    ) async throws -> [HackersPub.CreateNoteMediumInput] {
        try await self.upload(snapshot: attachments.wrappedValue, upload: upload)
    }

    func upload(
        snapshot: [PendingPhotoAttachment],
        upload: (PendingPhotoAttachment) async throws -> String
    ) async throws -> [HackersPub.CreateNoteMediumInput] {
        try await ComposePhotoUploadCoordinator.upload(
            attachments: snapshot,
            cachedMediumID: { attachment in
                attachments.wrappedValue
                    .first(where: { $0.id == attachment.id })?
                    .uploadedMediumID
            },
            upload: { attachment in
                try await upload(attachment)
            },
            cacheMediumID: { index, mediumID in
                guard snapshot.indices.contains(index) else { return }

                var currentAttachments = attachments.wrappedValue
                guard let currentIndex = currentAttachments.firstIndex(
                    where: { $0.id == snapshot[index].id }
                ) else {
                    return
                }
                currentAttachments[currentIndex].recordUploadedMedium(id: mediumID)
                attachments.wrappedValue = currentAttachments
            },
            makeMedium: { attachment, mediumID in
                HackersPub.CreateNoteMediumInput(
                    alt: attachment.alt.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    mediumId: mediumID
                )
            }
        )
    }
}

struct ComposePhotoAttachmentsSection: View {
    @Binding var attachments: [PendingPhotoAttachment]
    let isLoading: Bool
    let isDisabled: Bool
    let onEdit: (PendingPhotoAttachment.ID) -> Void
    let onDelete: (PendingPhotoAttachment.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    NSLocalizedString(
                        "compose.photos.title",
                        comment: "Selected photos title"
                    ),
                    systemImage: "photo"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach($attachments) { $attachment in
                        ComposePhotoAttachmentCard(
                            attachment: $attachment,
                            isDisabled: isDisabled,
                            onEdit: { onEdit(attachment.id) },
                            onDelete: { onDelete(attachment.id) }
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
}

private struct ComposePhotoAttachmentCard: View {
    @Binding var attachment: PendingPhotoAttachment
    let isDisabled: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var trimmedAltText: String {
        attachment.alt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
                .accessibilityLabel(
                    NSLocalizedString(
                        "compose.photos.delete",
                        comment: "Delete photo button"
                    )
                )
            }

            Button(action: onEdit) {
                HStack(spacing: 6) {
                    Image(
                        systemName: trimmedAltText.isEmpty
                            ? "text.badge.plus"
                            : "checkmark.circle.fill"
                    )
                    .foregroundStyle(
                        trimmedAltText.isEmpty ? Color.secondary : Color.green
                    )
                    Text(
                        trimmedAltText.isEmpty
                            ? NSLocalizedString(
                                "compose.photos.alt.add",
                                comment: "Add alt text"
                            )
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
        .disabled(isDisabled)
    }
}

struct ComposePhotoAttachmentDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var attachment: PendingPhotoAttachment
    let onGenerateAltText: () async throws -> Void
    @State private var isGeneratingAltText = false
    @State private var generationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(uiImage: attachment.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(
                            EdgeInsets(
                                top: 12,
                                leading: 12,
                                bottom: 12,
                                trailing: 12
                            )
                        )
                }

                Section {
                    TextField(
                        NSLocalizedString(
                            "compose.photos.altPlaceholder",
                            comment: "Photo alt text placeholder"
                        ),
                        text: $attachment.alt,
                        axis: .vertical
                    )
                    .lineLimit(3 ... 6)

                    Button {
                        Task { @MainActor in
                            isGeneratingAltText = true
                            defer { isGeneratingAltText = false }
                            do {
                                try await onGenerateAltText()
                            } catch is CancellationError {
                                return
                            } catch {
                                generationError = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack {
                            if isGeneratingAltText {
                                ProgressView()
                            } else {
                                Image(systemName: "wand.and.sparkles")
                            }
                            Text(
                                NSLocalizedString(
                                    "compose.photos.alt.generate",
                                    comment: "Generate photo alt text button"
                                )
                            )
                        }
                    }
                    .disabled(isGeneratingAltText)
                } footer: {
                    Text(
                        NSLocalizedString(
                            "compose.photos.alt.footer",
                            comment: "Alt text guidance"
                        )
                    )
                }
            }
            .navigationTitle(
                NSLocalizedString(
                    "compose.photos.details",
                    comment: "Photo details title"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                NSLocalizedString(
                    "compose.photos.alt.generateError.title",
                    comment: "Generate photo alt text error title"
                ),
                isPresented: Binding(
                    get: { generationError != nil },
                    set: { if !$0 { generationError = nil } }
                )
            ) {
                Button(NSLocalizedString("compose.error.ok", comment: "OK button")) {
                    generationError = nil
                }
            } message: {
                if let generationError {
                    Text(generationError)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        NSLocalizedString(
                            "settings.done",
                            comment: "Done button"
                        )
                    ) {
                        dismiss()
                    }
                }
            }
        }
    }
}
