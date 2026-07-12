import CryptoKit
import Foundation

protocol MediumUploadClock: Sendable {
    func now() -> Date
}

struct SystemMediumUploadClock: MediumUploadClock {
    func now() -> Date {
        Date()
    }
}

struct MediumUploadCheckpointScope: Hashable, Sendable {
    fileprivate let accountOrSessionIdentifier: String

    var isValid: Bool {
        !accountOrSessionIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(accountOrSessionIdentifier: String) {
        self.accountOrSessionIdentifier = accountOrSessionIdentifier
    }
}

protocol MediumUploadScopeProviding: Sendable {
    func currentScope() async throws -> MediumUploadCheckpointScope
}

struct LiveMediumUploadScopeProvider: MediumUploadScopeProviding {
    func currentScope() async throws -> MediumUploadCheckpointScope {
        let sessionToken = await MainActor.run { AuthManager.shared.sessionToken }
        guard let sessionToken else {
            throw MediumUploadError.notAuthenticated
        }
        return MediumUploadCheckpointScope(accountOrSessionIdentifier: sessionToken)
    }
}

struct MediumUploadCheckpointKey: Codable, Hashable, Sendable {
    static let currentVersion = 1

    let version: Int
    let scopeDigest: String
    let contentType: String
    let byteCount: Int
    let contentDigest: String

    init(scope: MediumUploadCheckpointScope, contentType: String, data: Data) {
        version = Self.currentVersion
        scopeDigest = Self.digest(Data(scope.accountOrSessionIdentifier.utf8))
        self.contentType = contentType
        byteCount = data.count
        contentDigest = Self.digest(data)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum MediumUploadCheckpointState: String, Codable, Sendable {
    case started
    case uploading
    case uploaded
    case finishPending
    case completed
}

struct MediumUploadCheckpointHeader: Codable, Equatable, Sendable {
    let name: String
    let value: String
}

struct MediumUploadCheckpoint: Codable, Equatable, Sendable {
    let key: MediumUploadCheckpointKey
    let uploadID: String
    let uploadURL: URL
    let method: String
    let headers: [MediumUploadCheckpointHeader]
    let expiresAt: Date
    var state: MediumUploadCheckpointState
    var completedMedium: UploadedMedium?

    init(
        key: MediumUploadCheckpointKey,
        uploadID: String,
        uploadURL: URL,
        method: String,
        headers: [MediumUploadCheckpointHeader],
        expiresAt: Date,
        state: MediumUploadCheckpointState,
        completedMedium: UploadedMedium? = nil
    ) {
        self.key = key
        self.uploadID = uploadID
        self.uploadURL = uploadURL
        self.method = method
        self.headers = headers
        self.expiresAt = expiresAt
        self.state = state
        self.completedMedium = completedMedium
    }
}

protocol MediumUploadCheckpointStore: Sendable {
    func loadCheckpoint(for key: MediumUploadCheckpointKey) async throws -> MediumUploadCheckpoint?
    func saveCheckpoint(_ checkpoint: MediumUploadCheckpoint) async throws
    func removeCheckpoint(for key: MediumUploadCheckpointKey) async throws
}

enum MediumUploadCheckpointStoreError: Error {
    case corruptData
    case unsupportedVersion(Int)
    case readFailed(any Error)
    case writeFailed(any Error)
}

actor FileMediumUploadCheckpointStore: MediumUploadCheckpointStore {
    private struct Envelope: Codable {
        static let currentVersion = 1

        let version: Int
        var checkpoints: [MediumUploadCheckpoint]

        init(checkpoints: [MediumUploadCheckpoint] = []) {
            version = Self.currentVersion
            self.checkpoints = checkpoints
        }
    }

    private let fileURL: URL
    private let clock: any MediumUploadClock

    init(
        fileURL: URL = FileMediumUploadCheckpointStore.applicationFileURL(),
        clock: any MediumUploadClock = SystemMediumUploadClock()
    ) {
        self.fileURL = fileURL
        self.clock = clock
    }

    func loadCheckpoint(for key: MediumUploadCheckpointKey) async throws -> MediumUploadCheckpoint? {
        try readEnvelope().checkpoints.first { $0.key == key }
    }

    func saveCheckpoint(_ checkpoint: MediumUploadCheckpoint) async throws {
        var envelope = try readEnvelope()
        let now = clock.now()
        let expiredCount = envelope.checkpoints.count
        envelope.checkpoints.removeAll {
            $0.key != checkpoint.key && $0.state != .completed && $0.expiresAt <= now
        }
        if envelope.checkpoints.count != expiredCount {
            NSLog("Removed expired medium upload checkpoints during atomic save")
        }

        if let index = envelope.checkpoints.firstIndex(where: { $0.key == checkpoint.key }) {
            envelope.checkpoints[index] = checkpoint
        } else {
            envelope.checkpoints.append(checkpoint)
        }
        try writeEnvelope(envelope)
    }

    func removeCheckpoint(for key: MediumUploadCheckpointKey) async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        var envelope = try readEnvelope()
        let previousCount = envelope.checkpoints.count
        envelope.checkpoints.removeAll { $0.key == key }
        guard envelope.checkpoints.count != previousCount else { return }

        if envelope.checkpoints.isEmpty {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                throw MediumUploadCheckpointStoreError.writeFailed(error)
            }
        } else {
            try writeEnvelope(envelope)
        }
    }

    private func readEnvelope() throws -> Envelope {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Envelope()
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw MediumUploadCheckpointStoreError.readFailed(error)
        }

        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.version == Envelope.currentVersion else {
                deleteCorruptFile()
                throw MediumUploadCheckpointStoreError.unsupportedVersion(envelope.version)
            }
            return envelope
        } catch let error as MediumUploadCheckpointStoreError {
            throw error
        } catch {
            deleteCorruptFile()
            throw MediumUploadCheckpointStoreError.corruptData
        }
    }

    private func writeEnvelope(_ envelope: Envelope) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [
                    .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
                ]
            )
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        } catch {
            throw MediumUploadCheckpointStoreError.writeFailed(error)
        }
    }

    private func deleteCorruptFile() {
        do {
            try FileManager.default.removeItem(at: fileURL)
            NSLog("Deleted corrupt medium upload checkpoint data")
        } catch {
            NSLog("Failed to delete corrupt medium upload checkpoint data")
        }
    }

    private static func applicationFileURL() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("HackersPub", isDirectory: true)
            .appendingPathComponent("medium-upload-checkpoints.json")
    }
}
