import Foundation
@testable import HackersPub
import Testing

@Suite(.serialized)
struct MediumUploadCorruptFileCleanupTests {
    @Test
    func corruptCheckpointContainingUploadSecretsIsDeletedWithoutQuarantineCopy() async throws {
        let fixture = MediumUploadCheckpointFixture(finishSteps: [.success])
        let directoryURL = fixture.checkpointFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let presignedURL = "https://storage.example/upload?X-Amz-Credential=sensitive-credential"
        let sensitiveHeader = "Bearer sensitive-upload-token"
        let corruptJSON = """
        {"version":1,"checkpoints":[{"uploadURL":"\(presignedURL)",
        "headers":[{"name":"Authorization","value":"\(sensitiveHeader)"}]
        """
        try Data(corruptJSON.utf8).write(to: fixture.checkpointFileURL)

        do {
            _ = try await fixture.makeService(
                scopeProvider: FixedMediumUploadScopeProvider("session-a")
            ).uploadImageData(checkpointTestImageData())
            Issue.record("Expected corrupt checkpoint data to fail explicitly")
        } catch let error as MediumUploadError {
            guard case .checkpointCorrupt = error else {
                Issue.record("Expected checkpointCorrupt, received \(error)")
                return
            }
        }

        let remainingFiles = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        #expect(remainingFiles.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fixture.checkpointFileURL.path))
        #expect(fixture.transport.snapshot().startRequests == 0)
        #expect(await fixture.controller.snapshotRequestCount() == 0)
    }
}
