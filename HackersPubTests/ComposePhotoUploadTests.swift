import Foundation
@testable import HackersPub
import SwiftUI
import Testing
import UIKit

@MainActor
struct ComposePhotoUploadTests {
    @Test func completedUploadIsRememberedForRetry() {
        var attachment = PendingPhotoAttachment(data: Data(), image: UIImage())

        #expect(attachment.requiresUpload)

        attachment.recordUploadedMedium(id: "medium-1")

        #expect(!attachment.requiresUpload)
        #expect(attachment.uploadedMediumID == "medium-1")
    }

    @Test func deletedAttachmentDoesNotKeepReusableMediumIdentity() {
        var attachment = PendingPhotoAttachment(data: Data(), image: UIImage())
        attachment.recordUploadedMedium(id: "medium-1")
        let deletedID = attachment.id
        var attachments = [attachment]

        attachments.removeAll { $0.id == deletedID }

        #expect(!attachments.contains { $0.uploadedMediumID == "medium-1" })
    }

    @Test func completedAttachmentUploadIsReusedAfterALaterAttachmentFails() async throws {
        let first = PendingPhotoAttachment(data: Data([1]), image: UIImage())
        let second = PendingPhotoAttachment(data: Data([2]), image: UIImage())
        let store = TestPhotoAttachmentStore(attachments: [first, second])
        let adapter = ComposePhotoAttachmentUploadAdapter(attachments: store.binding)

        do {
            _ = try await adapter.upload { attachment in
                let attempt = store.recordUpload(for: attachment.id)
                if attachment.id == second.id, attempt == 1 {
                    throw TestPhotoAttachmentUploadError.expectedFailure
                }
                return attachment.id == first.id ? "medium-first" : "medium-second"
            }
            Issue.record("The first upload should fail after caching the first attachment")
        } catch TestPhotoAttachmentUploadError.expectedFailure {
            // Expected: the first completed upload is retained for retry.
        }

        #expect(store.attachment(id: first.id)?.uploadedMediumID == "medium-first")
        #expect(store.attachment(id: second.id)?.uploadedMediumID == nil)

        let media = try await adapter.upload { attachment in
            let attempt = store.recordUpload(for: attachment.id)
            #expect(attempt == 2)
            return "medium-second"
        }

        #expect(media.count == 2)
        #expect(store.uploadCalls[first.id] == 1)
        #expect(store.uploadCalls[second.id] == 2)
        #expect(store.attachment(id: second.id)?.uploadedMediumID == "medium-second")
    }
}

@MainActor
private final class TestPhotoAttachmentStore {
    var attachments: [PendingPhotoAttachment]
    private(set) var uploadCalls: [UUID: Int] = [:]

    init(attachments: [PendingPhotoAttachment]) {
        self.attachments = attachments
    }

    var binding: Binding<[PendingPhotoAttachment]> {
        Binding(
            get: { self.attachments },
            set: { self.attachments = $0 }
        )
    }

    func attachment(id: UUID) -> PendingPhotoAttachment? {
        attachments.first { $0.id == id }
    }

    func recordUpload(for id: UUID) -> Int {
        uploadCalls[id, default: 0] += 1
        return uploadCalls[id, default: 0]
    }
}

private enum TestPhotoAttachmentUploadError: Error {
    case expectedFailure
}
