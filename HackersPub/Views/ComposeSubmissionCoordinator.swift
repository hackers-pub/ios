import Combine
import Foundation

enum ComposeSubmissionAttempt<Result> {
    case rejected
    case completed(Result)
}

struct ComposePreparedSubmission<Prepared> {
    let revision: ComposeSubmissionRevision
    let value: Prepared
}

struct ComposeSubmissionRevision: Equatable, Hashable {
    fileprivate let coordinatorIdentifier: UUID
    fileprivate let identifier: UInt64
}

struct ComposePhotoLoadingToken: Equatable {
    fileprivate let coordinatorIdentifier: UUID
    fileprivate let identifier: UInt64
    let attachmentIDs: Set<UUID>
    let capacity: Int
}

struct ComposePreparedPhotoSelection<Item> {
    let token: ComposePhotoLoadingToken
    let items: [Item]
    let omittedForLimitCount: Int
}

@MainActor
final class ComposeSubmissionCoordinator: ObservableObject {
    @Published private(set) var isSubmitting = false
    @Published private(set) var isLoadingPhotos = false

    var isBusy: Bool {
        isSubmitting || isLoadingPhotos
    }

    private enum SubmissionPhase: Equatable {
        case preparing(UInt64)
        case prepared(UInt64)
        case running(UInt64)

        var identifier: UInt64 {
            switch self {
            case let .preparing(identifier), let .prepared(identifier), let .running(identifier):
                identifier
            }
        }
    }

    private var nextIdentifier: UInt64 = 0
    private let coordinatorIdentifier = UUID()
    private var submissionPhase: SubmissionPhase?
    private var photoLoadingToken: ComposePhotoLoadingToken?

    func prepareSubmission<Prepared>(
        _ prepare: () throws -> Prepared
    ) throws -> ComposePreparedSubmission<Prepared>? {
        try prepareSubmission { (_: ComposeSubmissionRevision) in
            try prepare()
        }
    }

    func prepareSubmission<Prepared>(
        _ prepare: (ComposeSubmissionRevision) throws -> Prepared
    ) throws -> ComposePreparedSubmission<Prepared>? {
        guard submissionPhase == nil, photoLoadingToken == nil else { return nil }

        let revision = ComposeSubmissionRevision(
            coordinatorIdentifier: coordinatorIdentifier,
            identifier: makeIdentifier()
        )
        submissionPhase = .preparing(revision.identifier)
        isSubmitting = true

        do {
            let value = try prepare(revision)
            guard submissionPhase == .preparing(revision.identifier) else {
                finishSubmission(identifier: revision.identifier)
                return nil
            }
            submissionPhase = .prepared(revision.identifier)
            return ComposePreparedSubmission(revision: revision, value: value)
        } catch {
            finishSubmission(identifier: revision.identifier)
            throw error
        }
    }

    func perform<Prepared, Uploaded, Result>(
        _ prepared: ComposePreparedSubmission<Prepared>,
        upload: @MainActor (Prepared) async throws -> Uploaded,
        submit: @MainActor (Prepared, Uploaded) async throws -> Result
    ) async throws -> ComposeSubmissionAttempt<Result> {
        guard submissionPhase == .prepared(prepared.revision.identifier) else { return .rejected }
        submissionPhase = .running(prepared.revision.identifier)
        defer { finishSubmission(identifier: prepared.revision.identifier) }

        try Task.checkCancellation()
        let uploaded = try await upload(prepared.value)
        try Task.checkCancellation()
        let result = try await submit(prepared.value, uploaded)
        return .completed(result)
    }

    func remainingPhotoCapacity(
        currentAttachmentIDs: Set<UUID>,
        maximumAttachmentCount: Int
    ) -> Int {
        max(0, maximumAttachmentCount - currentAttachmentIDs.count)
    }

    func preparePhotoSelection<Item>(
        items: [Item],
        currentAttachmentIDs: Set<UUID>,
        maximumAttachmentCount: Int
    ) -> ComposePreparedPhotoSelection<Item>? {
        guard submissionPhase == nil, photoLoadingToken == nil, !items.isEmpty else { return nil }

        let capacity = remainingPhotoCapacity(
            currentAttachmentIDs: currentAttachmentIDs,
            maximumAttachmentCount: maximumAttachmentCount
        )
        guard capacity > 0 else { return nil }

        let acceptedItems = Array(items.prefix(capacity))
        let token = ComposePhotoLoadingToken(
            coordinatorIdentifier: coordinatorIdentifier,
            identifier: makeIdentifier(),
            attachmentIDs: currentAttachmentIDs,
            capacity: capacity
        )
        photoLoadingToken = token
        isLoadingPhotos = true
        return ComposePreparedPhotoSelection(
            token: token,
            items: acceptedItems,
            omittedForLimitCount: items.count - acceptedItems.count
        )
    }

    func loadedPhotosToAppend<Photo>(
        _ loadedPhotos: [Photo],
        for token: ComposePhotoLoadingToken,
        currentAttachmentIDs: Set<UUID>
    ) -> [Photo]? {
        guard photoLoadingToken == token,
              currentAttachmentIDs == token.attachmentIDs
        else {
            return nil
        }

        return Array(loadedPhotos.prefix(token.capacity))
    }

    func finishPhotoLoading(_ token: ComposePhotoLoadingToken) {
        guard photoLoadingToken == token else { return }
        photoLoadingToken = nil
        isLoadingPhotos = false
    }

    private func makeIdentifier() -> UInt64 {
        nextIdentifier &+= 1
        return nextIdentifier
    }

    private func finishSubmission(identifier: UInt64) {
        guard submissionPhase?.identifier == identifier else { return }
        submissionPhase = nil
        isSubmitting = false
    }
}

enum ComposePhotoUploadCoordinator {
    @MainActor
    static func upload<Attachment, Medium>(
        attachments: [Attachment],
        cachedMediumID: (Attachment) -> String?,
        upload: (Attachment) async throws -> String,
        cacheMediumID: (Int, String) -> Void,
        makeMedium: (Attachment, String) -> Medium
    ) async throws -> [Medium] {
        var media: [Medium] = []
        for index in attachments.indices {
            try Task.checkCancellation()

            let mediumID: String
            if let cachedID = cachedMediumID(attachments[index]) {
                mediumID = cachedID
            } else {
                let attachment = attachments[index]
                mediumID = try await upload(attachment)
                cacheMediumID(index, mediumID)
            }

            media.append(makeMedium(attachments[index], mediumID))
        }
        return media
    }
}
