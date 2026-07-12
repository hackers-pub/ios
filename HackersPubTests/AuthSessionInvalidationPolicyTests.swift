// swiftlint:disable file_length
import ApolloAPI
import AuthenticationServices
import Foundation
@testable import HackersPub
import Security
import Testing
import UniformTypeIdentifiers

private struct CollidingJSONDictionaryKey: Hashable, Sendable, CustomStringConvertible {
    let identifier: String

    var description: String {
        "same-key"
    }
}

struct AuthSessionInvalidationPolicyTests {
    @Test func clearsLocalSessionForCompleteUnauthenticatedViewerResponse() {
        #expect(
            AuthSessionInvalidationPolicy.shouldClearLocalSession(
                hasResponseData: true,
                viewerIsNil: true,
                graphQLErrorsPresent: false,
                httpStatusCode: nil
            )
        )
    }

    @Test func onlyClearsLocalSessionForTypedUnauthorizedHTTPStatuses() {
        #expect(
            AuthSessionInvalidationPolicy.shouldClearLocalSession(
                hasResponseData: false,
                viewerIsNil: false,
                graphQLErrorsPresent: false,
                httpStatusCode: 401
            )
        )
        #expect(
            AuthSessionInvalidationPolicy.shouldClearLocalSession(
                hasResponseData: false,
                viewerIsNil: false,
                graphQLErrorsPresent: false,
                httpStatusCode: 403
            )
        )
        #expect(!AuthSessionInvalidationPolicy.shouldClearLocalSession(
            hasResponseData: false,
            viewerIsNil: false,
            graphQLErrorsPresent: false,
            httpStatusCode: 500
        ))
        #expect(!AuthSessionInvalidationPolicy.shouldClearLocalSession(
            hasResponseData: true,
            viewerIsNil: true,
            graphQLErrorsPresent: true,
            httpStatusCode: nil
        ))
    }
}

struct KeychainPersistencePolicyTests {
    @Test func addsOnlyWhenAnUpdateFindsNoExistingItem() {
        #expect(KeychainPersistencePolicy.saveAction(forUpdateStatus: errSecSuccess) == .complete)
        #expect(KeychainPersistencePolicy.saveAction(forUpdateStatus: errSecItemNotFound) == .add)
        #expect(KeychainPersistencePolicy.saveAction(forUpdateStatus: errSecInteractionNotAllowed) == .fail)
    }

    @Test func retriesSessionLoadingWhenProtectedDataIsUnavailable() {
        #expect(KeychainPersistencePolicy.shouldRetrySessionLoad(for: errSecInteractionNotAllowed))
        #expect(!KeychainPersistencePolicy.shouldRetrySessionLoad(for: errSecItemNotFound))
    }
}

struct SessionInvalidationPersistenceTests {
    @Test
    func recognizesTheLegacyPendingTombstoneForBoundMigration() async throws {
        let suiteName = "SessionInvalidationPersistenceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacyKey = "legacy.pending"
        defaults.set(true, forKey: legacyKey)
        let store = UserDefaultsSessionInvalidationStore(
            defaults: defaults,
            markerIDKey: "marker.id",
            markerFingerprintKey: "marker.fingerprint",
            legacyPendingKey: legacyKey
        )

        let marker = await store.pendingMarker()

        #expect(marker?.isLegacy == true)
        #expect(marker?.matches(token: "old-token") == false)
    }
}

struct AuthPresentationPolicyTests {
    @Test func usesLocalizedKeysForEverySignInError() {
        #expect(AuthError.loginFailed.localizationKey == "signIn.error.loginFailed")
        #expect(AuthError.accountNotFound.localizationKey == "signIn.error.accountNotFound")
        #expect(AuthError.verificationFailed.localizationKey == "signIn.error.verificationFailed")
        #expect(AuthError.passkeyFailed.localizationKey == "passkey.error.failed")
    }

    @Test func keepsTheFullBCP47LanguageTagForTheDefaultLocale() {
        #expect(
            AuthLocalePolicy.effectiveLocale(
                requested: nil,
                currentLocale: Locale(identifier: "zh-Hant-TW")
            ) == "zh-Hant-TW"
        )
        #expect(
            AuthLocalePolicy.effectiveLocale(
                requested: "ko-KR",
                currentLocale: Locale(identifier: "en-US")
            ) == "ko-KR"
        )
    }

    @Test func makesAPasskeyListFailureRetryable() {
        var state = PasskeyListLoadState.idle
        state.beginLoading()
        #expect(state == .loading)
        state.fail()
        #expect(state == .failed)
        state.beginLoading()
        state.finishLoading()
        #expect(state == .idle)
    }
}

struct PasskeyAuthorizationPolicyTests {
    @Test func mapsCancellationToASilentDomainResult() {
        let cancelled = PasskeyAuthorizationErrorPolicy.serviceError(for: .canceled)

        #expect(cancelled == .cancelled)
        #expect(!PasskeyAuthorizationErrorPolicy.shouldPresent(cancelled))
        #expect(PasskeyAuthorizationErrorPolicy.shouldPresent(.authorizationFailed))
    }
}

struct PasskeyRequestLifecycleTests {
    @Test func rejectsMissingAnchorsAndConcurrentRequests() throws {
        var slot = PasskeyRequestSlot()

        #expect(throws: PasskeyServiceError.presentationAnchorUnavailable) {
            try slot.reserve(presentationAnchorAvailable: false)
        }

        try slot.reserve(presentationAnchorAvailable: true)
        #expect(throws: PasskeyServiceError.requestInProgress) {
            try slot.reserve(presentationAnchorAvailable: true)
        }
    }

    @Test func releasesTheRequestSlotAndCompletionOnlyOnce() throws {
        var slot = PasskeyRequestSlot()
        var completionGate = PasskeyRequestCompletionGate()

        try slot.reserve(presentationAnchorAvailable: true)
        let completedFirstTime = completionGate.finish()
        let completedSecondTime = completionGate.finish()
        #expect(completedFirstTime)
        #expect(!completedSecondTime)

        slot.release()
        try slot.reserve(presentationAnchorAvailable: true)
    }
}

struct PasskeyRegistrationPayloadTests {
    @Test func rejectsRegistrationOptionsWithoutAUserName() {
        let user: ApolloAPI.JSONEncodableDictionary = ["id": "dXNlci1pZA"]

        #expect(throws: PasskeyServiceError.invalidOptions) {
            try PasskeyRegistrationOptions(json: registrationOptionsJSON(user: user))
        }
    }

    @Test func rejectsRegistrationOptionsWithAnEmptyUserID() {
        let user: ApolloAPI.JSONEncodableDictionary = [
            "id": "",
            "name": "MacBook"
        ]

        #expect(throws: PasskeyServiceError.invalidUserID) {
            try PasskeyRegistrationOptions(json: registrationOptionsJSON(user: user))
        }
    }

    @Test func serializesEmptyUserHandlesAsJSONNull() {
        let missingUserHandle = PasskeyWebAuthnPayload.userHandleJSONValue(from: nil)
        let emptyUserHandle = PasskeyWebAuthnPayload.userHandleJSONValue(from: Data())
        let populatedUserHandle = PasskeyWebAuthnPayload.userHandleJSONValue(from: Data([0x01]))

        #expect(missingUserHandle is NSNull)
        #expect(emptyUserHandle is NSNull)
        #expect(populatedUserHandle as? String == "AQ")
    }

    private func registrationOptionsJSON(
        user: ApolloAPI.JSONEncodableDictionary
    ) -> HackersPub.JSON {
        let relyingParty: ApolloAPI.JSONEncodableDictionary = ["id": "hackers.pub"]
        let options: ApolloAPI.JSONEncodableDictionary = [
            "challenge": "Y2hhbGxlbmdl",
            "rp": relyingParty,
            "user": user
        ]
        return HackersPub.JSON(encodableDictionary: options)
    }
}

struct SignInFlowPolicyTests {
    @Test func trimsUsernamesAndRejectsWhitespaceOnlyInput() {
        #expect(SignInFlowPolicy.trimmedUsername("  alice  ") == "alice")
        #expect(SignInFlowPolicy.canRequestSignInLink(username: "\n \t") == false)
    }

    @Test func recoversWhenVerificationHasNoSessionToken() {
        #expect(SignInFlowPolicy.verificationAction(loginToken: nil) == .restart)
        #expect(SignInFlowPolicy.verificationAction(loginToken: "") == .restart)
        #expect(SignInFlowPolicy.verificationAction(loginToken: "token") == .verify("token"))
    }
}

struct MediumUploadPolicyTests {
    @Test func preservesOriginalPNGBytesAndMIMEType() throws {
        let encodedPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8A" +
            "AusB9Y9JZYkAAAAASUVORK5CYII="
        let data = try #require(
            Data(base64Encoded: encodedPNG)
        )

        let payload = try ImagePayloadPolicy.payload(from: data)

        #expect(payload.data == data)
        #expect(payload.contentType == "image/png")
        #expect(payload.uniformTypeIdentifier == UTType.png.identifier)
    }

    @Test func rejectsInvalidImagePayloads() {
        #expect(throws: ImagePayloadError.invalidImage) {
            try ImagePayloadPolicy.payload(from: Data())
        }
    }

    @Test func boundsRetriesToTransientPutFailuresAndInt32Lengths() {
        #expect(MediumUploadRetryPolicy.contentLength(for: Int(Int32.max)) == Int32.max)
        #expect(MediumUploadRetryPolicy.contentLength(for: Int(Int32.max) + 1) == nil)
        #expect(MediumUploadRetryPolicy.shouldRetry(error: MediumUploadError.uploadTargetFailed(500), attempt: 0))
        #expect(MediumUploadRetryPolicy.shouldRetry(error: URLError(.timedOut), attempt: 1))
        #expect(!MediumUploadRetryPolicy.shouldRetry(error: MediumUploadError.uploadTargetFailed(400), attempt: 0))
        #expect(!MediumUploadRetryPolicy.shouldRetry(error: MediumUploadError.uploadTargetFailed(503), attempt: 2))
    }
}

struct ImageDownloadPolicyTests {
    @Test func preservesOriginalImageBytesForPhotoLibraryResource() throws {
        let encodedPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8A" +
            "AusB9Y9JZYkAAAAASUVORK5CYII="
        let data = try #require(Data(base64Encoded: encodedPNG))

        let resource = try ImageDownloadService.photoResource(from: data)

        #expect(resource.data == data)
        #expect(resource.uniformTypeIdentifier == UTType.png.identifier)
    }

    @Test func rejectsNonSuccessHTTPDownloadResponses() throws {
        let url = try #require(URL(string: "https://example.com/image.png"))
        let success = try #require(
            HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)
        )
        let failure = try #require(
            HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
        )

        try ImageDownloadResponsePolicy.validate(success)
        #expect(throws: ImageDownloadServiceError.httpStatus(404)) {
            try ImageDownloadResponsePolicy.validate(failure)
        }
    }
}

struct JSONCanonicalizationPolicyTests {
    @Test func preservesCollidingStringifiedDictionaryKeysWithoutTrapping() {
        let values: [AnyHashable: Any] = [
            AnyHashable(1): "integer",
            AnyHashable("1"): "string"
        ]
        var reverseInsertionOrder: [AnyHashable: Any] = [:]
        reverseInsertionOrder[AnyHashable("1")] = "string"
        reverseInsertionOrder[AnyHashable(1)] = "integer"
        let oneEntry: [AnyHashable: Any] = [AnyHashable(1): "integer"]

        let canonicalValue = JSONCanonicalizationPolicy.canonicalString(fromAny: values)

        #expect(
            JSONCanonicalizationPolicy.dictionaryKeyValidation(for: values) == .stringifiedKeyCollision
        )
        #expect(canonicalValue == JSONCanonicalizationPolicy.canonicalString(fromAny: reverseInsertionOrder))
        #expect(canonicalValue != JSONCanonicalizationPolicy.canonicalString(fromAny: oneEntry))
        #expect(canonicalValue.contains("integer"))
        #expect(canonicalValue.contains("string"))
    }

    @Test func appliesCollisionSafeCanonicalizationThroughJSONScalar() {
        let values: [CollidingJSONDictionaryKey: String] = [
            CollidingJSONDictionaryKey(identifier: "first"): "integer",
            CollidingJSONDictionaryKey(identifier: "second"): "string"
        ]
        let oneEntry: [CollidingJSONDictionaryKey: String] = [
            CollidingJSONDictionaryKey(identifier: "first"): "integer"
        ]
        var reverseInsertionOrder: [CollidingJSONDictionaryKey: String] = [:]
        reverseInsertionOrder[CollidingJSONDictionaryKey(identifier: "second")] = "string"
        reverseInsertionOrder[CollidingJSONDictionaryKey(identifier: "first")] = "integer"

        let completeJSON = HackersPub.JSON(value: values)
        let partialJSON = HackersPub.JSON(value: oneEntry)

        #expect(completeJSON == HackersPub.JSON(value: reverseInsertionOrder))
        #expect(completeJSON != partialJSON)
    }

    @Test func preservesOrderIndependentCanonicalizationForValidJSONObjects() {
        let first: JSONEncodableDictionary = ["b": 2, "a": "one"]
        let second: JSONEncodableDictionary = ["a": "one", "b": 2]

        #expect(
            HackersPub.JSON(encodableDictionary: first) == HackersPub.JSON(encodableDictionary: second)
        )
    }
}

struct ActorRelationshipFetchPolicyTests {
    @Test func distinguishesUsablePartialDataFromErrorOnlyAndNotFoundResponses() throws {
        #expect(
            ActorRelationshipFetchPolicy.outcome(
                graphQLErrorsPresent: true,
                actorPresent: true
            ) == .found
        )
        #expect(
            ActorRelationshipFetchPolicy.outcome(
                graphQLErrorsPresent: true,
                actorPresent: false
            ) == .queryFailed
        )
        #expect(
            ActorRelationshipFetchPolicy.outcome(
                graphQLErrorsPresent: false,
                actorPresent: false
            ) == .notFound
        )

        let relationship = actorRelationshipState()
        #expect(
            try ActorRelationshipService.resolveFetchResult(
                graphQLErrorsPresent: true,
                relationship: relationship
            ) == relationship
        )
        do {
            _ = try ActorRelationshipService.resolveFetchResult(
                graphQLErrorsPresent: true,
                relationship: nil
            )
            Issue.record("Expected queryFailed relationship response")
        } catch let error as ActorRelationshipServiceError {
            guard case .queryFailed = error else {
                Issue.record("Expected queryFailed relationship response, received \(error)")
                return
            }
        } catch {
            Issue.record("Expected ActorRelationshipServiceError, received \(error)")
        }
        #expect(
            try ActorRelationshipService.resolveFetchResult(
                graphQLErrorsPresent: false,
                relationship: nil
            ) == nil
        )
    }

    @Test func acceptsTheCurrentRelationshipRequestForItsActor() {
        let gate = ActorRelationshipStateUpdateGate()
        let currentRequest = gate.begin(handle: "@alice")

        #expect(gate.allows(currentRequest, currentHandle: "@alice"))
    }

    @Test func rejectsStaleRelationshipRequestsAndRequestsForAnotherActor() {
        let gate = ActorRelationshipStateUpdateGate()
        let staleRequest = gate.begin(handle: "@alice")
        let currentRequest = gate.begin(handle: "@alice")

        #expect(!gate.allows(staleRequest, currentHandle: "@alice"))
        #expect(gate.allows(currentRequest, currentHandle: "@alice"))
        #expect(!gate.allows(currentRequest, currentHandle: "@bob"))
    }

    @Test func invalidatingTheRelationshipGatePreventsLateWrites() {
        let gate = ActorRelationshipStateUpdateGate()
        let pendingRequest = gate.begin(handle: "@alice")

        gate.invalidate()
        #expect(!gate.allows(pendingRequest, currentHandle: "@alice"))
    }
}

private func actorRelationshipState() -> ActorRelationshipState {
    ActorRelationshipState(
        actorId: "actor-id",
        handle: "@alice",
        isViewer: false,
        viewerFollows: false,
        followsViewer: false,
        viewerBlocks: false
    )
}
