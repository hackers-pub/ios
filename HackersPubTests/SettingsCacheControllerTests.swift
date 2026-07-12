import Apollo
import ApolloSQLite
import Foundation
@testable import HackersPub
import Testing

@Suite(.serialized)
struct SettingsCacheControllerTests {
    @Test func vacuumPolicyControlsDisplayedPhysicalMetricAcrossThreeFreshDatabases() throws {
        for _ in 0 ..< 3 {
            let directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directoryURL) }

            let vacuumingFileURL = directoryURL.appendingPathComponent("vacuuming.sqlite")
            let defaultFileURL = directoryURL.appendingPathComponent("apollo-default.sqlite")
            let configuration = ApolloCacheConfiguration(fileURL: vacuumingFileURL)
            let vacuumingCache = try #require(
                configuration.makeNormalizedCache() as? SQLiteNormalizedCache
            )
            let defaultCache = try makeDefaultSQLiteCache(fileURL: defaultFileURL)
            let emptyDatabaseSize = try ApolloSQLiteCacheMetric.physicalSize(at: vacuumingFileURL)
            let records = cacheRecords()

            let vacuumingSizes = try clearSizes(
                cache: vacuumingCache,
                fileURL: vacuumingFileURL,
                records: records
            )
            let defaultSizes = try clearSizes(
                cache: defaultCache,
                fileURL: defaultFileURL,
                records: records
            )

            #expect(vacuumingSizes.before > 1_000_000)
            #expect(vacuumingSizes.after * 4 < vacuumingSizes.before)
            #expect(vacuumingSizes.after <= emptyDatabaseSize + 16384)
            #expect(defaultSizes.after == defaultSizes.before)
        }
    }

    @Test func physicalMetricTreatsCocoaAndPOSIXMissingErrorsAsZero() throws {
        let fileURL = URL(fileURLWithPath: "/cache/apollo.sqlite")
        let missingErrors = [
            NSError(
                domain: NSCocoaErrorDomain,
                code: CocoaError.Code.fileNoSuchFile.rawValue
            ),
            NSError(
                domain: NSCocoaErrorDomain,
                code: CocoaError.Code.fileReadNoSuchFile.rawValue
            ),
            NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(POSIXErrorCode.ENOENT.rawValue)
            )
        ]

        for missingError in missingErrors {
            let fileSystem = FileAttributesStub(results: [fileURL.path: .failure(missingError)])
            #expect(try ApolloSQLiteCacheMetric.physicalSize(at: fileURL, fileSystem: fileSystem) == 0)
        }
    }

    @Test func physicalMetricRejectsMissingNonNumericAndNegativeSizes() {
        let fileURL = URL(fileURLWithPath: "/cache/apollo.sqlite")
        let invalidResults: [FileAttributeResult] = [
            .attributes([:]),
            .attributes([.size: "not-a-number"]),
            .size(-1)
        ]

        for invalidResult in invalidResults {
            let fileSystem = FileAttributesStub(results: [fileURL.path: invalidResult])
            do {
                _ = try ApolloSQLiteCacheMetric.physicalSize(at: fileURL, fileSystem: fileSystem)
                Issue.record("Expected invalid physical cache size to throw")
            } catch let ApolloSQLiteCacheMetricError.invalidFileSize(invalidURL) {
                #expect(invalidURL == fileURL)
            } catch {
                Issue.record("Unexpected physical cache size error: \(error)")
            }
        }
    }

    @Test func physicalMetricPropagatesPermissionAndIOErrors() {
        let fileURL = URL(fileURLWithPath: "/cache/apollo.sqlite")
        let failures = [
            NSError(
                domain: NSCocoaErrorDomain,
                code: CocoaError.Code.fileReadNoPermission.rawValue
            ),
            NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(POSIXErrorCode.EIO.rawValue)
            )
        ]

        for failure in failures {
            let fileSystem = FileAttributesStub(results: [fileURL.path: .failure(failure)])
            do {
                _ = try ApolloSQLiteCacheMetric.physicalSize(at: fileURL, fileSystem: fileSystem)
                Issue.record("Expected physical cache measurement to propagate \(failure)")
            } catch {
                let caughtError = error as NSError
                #expect(caughtError.domain == failure.domain)
                #expect(caughtError.code == failure.code)
            }
        }
    }

    @Test func vacuumingApolloStoreRemainsReusableAcrossConcurrentClearAndWrite() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("concurrent.sqlite")
        let configuration = ApolloCacheConfiguration(fileURL: fileURL)
        let store = ApolloStore(cache: configuration.makeNormalizedCache())
        let records = cacheRecords()

        async let publish: Void = store.publish(records: records)
        async let clear: Void = store.clearCache()
        try await publish
        try await clear

        try await store.publish(records: records)
        try await store.clearCache()
        #expect(try ApolloSQLiteCacheMetric.physicalSize(at: fileURL) < 100_000)
    }

    @Test func appSingletonClientUsesTheVacuumingNormalizedCacheConfiguration() async throws {
        let documentsURL = try #require(
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        )
        let fileURL = documentsURL.appendingPathComponent(ApolloCacheConfiguration.fileName)
        let records = cacheRecords()

        try await apolloClient.clearCache()
        let emptyDatabaseSize = try ApolloSQLiteCacheMetric.physicalSize(at: fileURL)
        try await apolloClient.store.publish(records: records)
        let sizeBeforeClear = try ApolloSQLiteCacheMetric.physicalSize(at: fileURL)
        try await apolloClient.clearCache()
        let sizeAfterClear = try ApolloSQLiteCacheMetric.physicalSize(at: fileURL)

        #expect(sizeBeforeClear > 1_000_000)
        #expect(sizeAfterClear * 4 < sizeBeforeClear)
        #expect(sizeAfterClear <= emptyDatabaseSize + 16384)
    }

    @Test func cacheSizePropagatesBackingFailure() async {
        let backing = CacheBackingSpy(size: 0, shouldFailMeasurement: true)
        let controller = SettingsCacheController(backing: backing)

        do {
            _ = try await controller.cacheSize()
            Issue.record("Expected cache size measurement failure to propagate")
        } catch CacheBackingSpyError.measurement {
            #expect(backing.events == [.measure])
        } catch {
            Issue.record("Unexpected cache size error: \(error)")
        }
    }

    @Test func clearAndMeasureReportsBestEffortWhenOnlyApolloCanReportFailures() async {
        let backing = CacheBackingSpy(size: 42)
        let controller = SettingsCacheController(backing: backing)

        let result = await controller.clearAndMeasure()

        #expect(result == .bestEffort(size: 42))
        #expect(backing.events == [.apollo, .kingfisherMemory, .kingfisherDisk, .urlCache, .measure])
    }

    @Test func clearAndMeasureReportsApolloFailureAfterClearingOtherCacheLayers() async {
        let backing = CacheBackingSpy(size: 7, shouldFailApolloClear: true)
        let controller = SettingsCacheController(backing: backing)

        let result = await controller.clearAndMeasure()

        #expect(result == .failure(size: 7))
        #expect(backing.events == [.apollo, .kingfisherMemory, .kingfisherDisk, .urlCache, .measure])
    }

    @Test func clearAndMeasureReportsMeasurementFailureWithoutInventingAZeroSize() async {
        let backing = CacheBackingSpy(size: 0, shouldFailMeasurement: true)
        let controller = SettingsCacheController(backing: backing)

        let result = await controller.clearAndMeasure()

        #expect(result == .failure(size: nil))
        #expect(backing.events == [.apollo, .kingfisherMemory, .kingfisherDisk, .urlCache, .measure])
    }
}

private func cacheRecords() -> RecordSet {
    let payload = String(repeating: "cache-data-", count: 2048)
    return RecordSet(records: (0 ..< 256).map { index in
        Record(key: "record.\(index)", ["payload": "\(index)-\(payload)"])
    })
}

private func makeDefaultSQLiteCache(fileURL: URL) throws -> SQLiteNormalizedCache {
    let database = try ApolloSQLiteDatabase(fileURL: fileURL)
    try database.setJournalMode(mode: .delete)
    return try SQLiteNormalizedCache(database: database)
}

private func clearSizes(
    cache: SQLiteNormalizedCache,
    fileURL: URL,
    records: RecordSet
) throws -> (before: Int64, after: Int64) {
    try withExtendedLifetime(cache) {
        _ = try cache.merge(records: records)
        let before = try ApolloSQLiteCacheMetric.physicalSize(at: fileURL)
        try cache.clear()
        return try (before, ApolloSQLiteCacheMetric.physicalSize(at: fileURL))
    }
}

private func sidecarURL(for fileURL: URL, suffix: String) -> URL {
    fileURL.deletingLastPathComponent().appendingPathComponent(fileURL.lastPathComponent + suffix)
}

private struct FileAttributesStub: ApolloSQLiteFileSystem {
    let results: [String: FileAttributeResult]

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        switch results[path] ?? .failure(
            NSError(domain: NSCocoaErrorDomain, code: CocoaError.Code.fileReadNoSuchFile.rawValue)
        ) {
        case let .size(size):
            return [.size: NSNumber(value: size)]
        case let .attributes(attributes):
            return attributes
        case let .failure(error):
            throw error
        }
    }
}

private enum FileAttributeResult {
    case size(Int64)
    case attributes([FileAttributeKey: Any])
    case failure(NSError)
}

private final class CacheBackingSpy: SettingsCacheBacking {
    enum Event: Equatable {
        case apollo
        case kingfisherMemory
        case kingfisherDisk
        case urlCache
        case measure
    }

    private let size: Int64
    private let shouldFailApolloClear: Bool
    private let shouldFailMeasurement: Bool
    private(set) var events: [Event] = []

    init(
        size: Int64,
        shouldFailApolloClear: Bool = false,
        shouldFailMeasurement: Bool = false
    ) {
        self.size = size
        self.shouldFailApolloClear = shouldFailApolloClear
        self.shouldFailMeasurement = shouldFailMeasurement
    }

    func clearApolloCache() async throws {
        events.append(.apollo)
        if shouldFailApolloClear {
            throw CacheBackingSpyError.apolloClear
        }
    }

    func clearKingfisherMemoryCache() {
        events.append(.kingfisherMemory)
    }

    func clearKingfisherDiskCache() async {
        events.append(.kingfisherDisk)
    }

    func clearSharedURLCache() {
        events.append(.urlCache)
    }

    func cacheSize() async throws -> Int64 {
        events.append(.measure)
        if shouldFailMeasurement {
            throw CacheBackingSpyError.measurement
        }
        return size
    }
}

private enum CacheBackingSpyError: Error {
    case apolloClear
    case measurement
}
