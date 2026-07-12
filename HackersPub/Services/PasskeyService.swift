import ApolloAPI
import AuthenticationServices
import Foundation
import UIKit

enum PasskeyServiceError: LocalizedError, Equatable {
    case invalidOptions
    case invalidChallenge
    case invalidUserID
    case unsupportedCredential
    case authorizationUnavailable
    case authorizationFailed
    case timedOut
    case cancelled
    case requestInProgress
    case presentationAnchorUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidOptions:
            return NSLocalizedString("passkey.error.invalidOptions", comment: "Invalid passkey options error")
        case .invalidChallenge:
            return NSLocalizedString("passkey.error.invalidChallenge", comment: "Invalid passkey challenge error")
        case .invalidUserID:
            return NSLocalizedString("passkey.error.invalidUserID", comment: "Invalid passkey user ID error")
        case .unsupportedCredential:
            return NSLocalizedString(
                "passkey.error.unsupportedCredential",
                comment: "Unsupported passkey credential error"
            )
        case .authorizationUnavailable:
            return NSLocalizedString(
                "passkey.error.authorizationUnavailable",
                comment: "Passkey authorization unavailable error"
            )
        case .authorizationFailed:
            return NSLocalizedString("passkey.error.authorizationFailed", comment: "Passkey authorization failed error")
        case .timedOut:
            return NSLocalizedString("passkey.error.timedOut", comment: "Passkey authorization timed out error")
        case .cancelled:
            return nil
        case .requestInProgress:
            return NSLocalizedString(
                "passkey.error.requestInProgress",
                comment: "Passkey request already in progress error"
            )
        case .presentationAnchorUnavailable:
            return NSLocalizedString(
                "passkey.error.presentationAnchorUnavailable",
                comment: "Passkey presentation anchor unavailable error"
            )
        }
    }
}

enum PasskeyAuthorizationErrorPolicy {
    static func serviceError(for code: ASAuthorizationError.Code) -> PasskeyServiceError {
        switch code {
        case .canceled:
            return .cancelled
        case .failed:
            return .authorizationUnavailable
        default:
            return .authorizationFailed
        }
    }

    static func shouldPresent(_ error: PasskeyServiceError) -> Bool {
        error != .cancelled
    }

    static func shouldPresent(_ error: any Error) -> Bool {
        if error is CancellationError {
            return false
        }
        if let serviceError = error as? PasskeyServiceError {
            return shouldPresent(serviceError)
        }
        return true
    }
}

enum PasskeyWebAuthnPayload {
    static func userHandleJSONValue(from userHandle: Data?) -> any ApolloAPI.JSONEncodable {
        guard let userHandle, !userHandle.isEmpty else {
            return NSNull()
        }
        return userHandle.base64URLEncodedString()
    }
}

struct PasskeyRequestSlot {
    private(set) var isReserved = false

    mutating func reserve(presentationAnchorAvailable: Bool) throws {
        guard !isReserved else {
            throw PasskeyServiceError.requestInProgress
        }
        guard presentationAnchorAvailable else {
            throw PasskeyServiceError.presentationAnchorUnavailable
        }
        isReserved = true
    }

    mutating func release() {
        isReserved = false
    }
}

struct PasskeyRequestCompletionGate {
    private var hasFinished = false

    mutating func finish() -> Bool {
        guard !hasFinished else {
            return false
        }
        hasFinished = true
        return true
    }
}

struct PasskeyCredentialDescriptor {
    let id: Data

    init?(json: ApolloAPI.JSONObject) {
        guard let idString = json["id"] as? String,
              let id = Data(base64URLEncoded: idString),
              !id.isEmpty
        else {
            return nil
        }
        self.id = id
    }
}

private func decodeCredentialDescriptors(
    from value: ApolloAPI.JSONValue?
) throws -> [PasskeyCredentialDescriptor] {
    guard let value else {
        return []
    }
    guard let values = value as? [ApolloAPI.JSONValue] else {
        throw PasskeyServiceError.invalidOptions
    }

    return try values.map { value in
        guard let object = value as? ApolloAPI.JSONObject,
              let descriptor = PasskeyCredentialDescriptor(json: object)
        else {
            throw PasskeyServiceError.invalidOptions
        }
        return descriptor
    }
}

struct PasskeyAuthenticationOptions {
    let challenge: Data
    let relyingPartyID: String
    let userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference
    let allowedCredentials: [PasskeyCredentialDescriptor]

    init(json: HackersPub.JSON) throws {
        guard let object = json.jsonObject else {
            throw PasskeyServiceError.invalidOptions
        }
        guard let challengeString = object["challenge"] as? String,
              let challenge = Data(base64URLEncoded: challengeString),
              !challenge.isEmpty
        else {
            throw PasskeyServiceError.invalidChallenge
        }

        guard let relyingPartyValue = object["rpId"] as? String else {
            throw PasskeyServiceError.invalidOptions
        }
        let relyingPartyID = relyingPartyValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !relyingPartyID.isEmpty else {
            throw PasskeyServiceError.invalidOptions
        }
        let userVerificationPreference = Self.userVerificationPreference(from: object["userVerification"])
        let credentials = try decodeCredentialDescriptors(from: object["allowCredentials"])

        self.challenge = challenge
        self.relyingPartyID = relyingPartyID
        self.userVerificationPreference = userVerificationPreference
        allowedCredentials = credentials
    }

    private static func userVerificationPreference(
        from value: ApolloAPI.JSONValue?
    ) -> ASAuthorizationPublicKeyCredentialUserVerificationPreference {
        switch value as? String {
        case "required":
            return .required
        case "discouraged":
            return .discouraged
        default:
            return .preferred
        }
    }
}

struct PasskeyRegistrationOptions {
    let challenge: Data
    let relyingPartyID: String
    let name: String
    let userID: Data
    let userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference
    let excludedCredentials: [PasskeyCredentialDescriptor]

    init(json: HackersPub.JSON) throws {
        guard let object = json.jsonObject else {
            throw PasskeyServiceError.invalidOptions
        }
        guard let challengeString = object["challenge"] as? String,
              let challenge = Data(base64URLEncoded: challengeString),
              !challenge.isEmpty
        else {
            throw PasskeyServiceError.invalidChallenge
        }
        guard let user = object["user"] as? ApolloAPI.JSONObject,
              let userIDString = user["id"] as? String,
              let userID = Data(base64URLEncoded: userIDString),
              !userID.isEmpty
        else {
            throw PasskeyServiceError.invalidUserID
        }

        guard let relyingParty = object["rp"] as? ApolloAPI.JSONObject,
              let relyingPartyID = relyingParty["id"] as? String,
              !relyingPartyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw PasskeyServiceError.invalidOptions
        }
        guard let userName = (user["name"] as? String) ?? (user["displayName"] as? String) else {
            throw PasskeyServiceError.invalidOptions
        }
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw PasskeyServiceError.invalidOptions
        }
        let authenticatorSelection = object["authenticatorSelection"] as? ApolloAPI.JSONObject
        let userVerificationPreference = Self.userVerificationPreference(
            from: authenticatorSelection?["userVerification"]
        )
        let credentials = try decodeCredentialDescriptors(from: object["excludeCredentials"])

        self.challenge = challenge
        self.relyingPartyID = relyingPartyID
        self.name = name
        self.userID = userID
        self.userVerificationPreference = userVerificationPreference
        excludedCredentials = credentials
    }

    private static func userVerificationPreference(
        from value: ApolloAPI.JSONValue?
    ) -> ASAuthorizationPublicKeyCredentialUserVerificationPreference {
        switch value as? String {
        case "required":
            return .required
        case "discouraged":
            return .discouraged
        default:
            return .preferred
        }
    }
}

@MainActor
final class PasskeyService: NSObject, PasskeyAuthorizing {
    static let shared = PasskeyService()

    private let presentationAnchorProvider: @MainActor () -> ASPresentationAnchor?
    private let requestFactory: any PasskeyAuthorizationRequestMaking
    private var activeRequest: PasskeyAuthorizationRequest?
    private var activeRequestID: UUID?
    private var requestSlot = PasskeyRequestSlot()

    override private init() {
        presentationAnchorProvider = { PasskeyService.currentPresentationAnchor() }
        requestFactory = SystemPasskeyAuthorizationRequestFactory()
        super.init()
    }

    init(
        presentationAnchorProvider: @escaping @MainActor () -> ASPresentationAnchor?,
        requestFactory: any PasskeyAuthorizationRequestMaking
    ) {
        self.presentationAnchorProvider = presentationAnchorProvider
        self.requestFactory = requestFactory
        super.init()
    }

    func authenticate(options: PasskeyAuthenticationOptions) async throws -> HackersPub.JSON {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: options.relyingPartyID
        )
        let request = provider.createCredentialAssertionRequest(challenge: options.challenge)
        request.userVerificationPreference = options.userVerificationPreference
        request.allowedCredentials = options.allowedCredentials.map {
            ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0.id)
        }

        let authorization = try await authorize(request)
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyServiceError.unsupportedCredential
        }

        let response: ApolloAPI.JSONEncodableDictionary = [
            "authenticatorData": credential.rawAuthenticatorData.base64URLEncodedString(),
            "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
            "signature": credential.signature.base64URLEncodedString(),
            "userHandle": PasskeyWebAuthnPayload.userHandleJSONValue(
                from: credential.userID as Data?
            )
        ]
        let value: ApolloAPI.JSONEncodableDictionary = [
            "id": credential.credentialID.base64URLEncodedString(),
            "rawId": credential.credentialID.base64URLEncodedString(),
            "type": "public-key",
            "response": response,
            "authenticatorAttachment": "platform"
        ]
        return HackersPub.JSON(encodableDictionary: value)
    }

    func register(options: PasskeyRegistrationOptions) async throws -> HackersPub.JSON {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: options.relyingPartyID
        )
        let request = provider.createCredentialRegistrationRequest(
            challenge: options.challenge,
            name: options.name,
            userID: options.userID
        )
        request.userVerificationPreference = options.userVerificationPreference
        request.excludedCredentials = options.excludedCredentials.map {
            ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0.id)
        }

        let authorization = try await authorize(request)
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
              let attestationObject = credential.rawAttestationObject
        else {
            throw PasskeyServiceError.unsupportedCredential
        }

        let response: ApolloAPI.JSONEncodableDictionary = [
            "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
            "attestationObject": attestationObject.base64URLEncodedString()
        ]
        let value: ApolloAPI.JSONEncodableDictionary = [
            "id": credential.credentialID.base64URLEncodedString(),
            "rawId": credential.credentialID.base64URLEncodedString(),
            "type": "public-key",
            "response": response,
            "authenticatorAttachment": "platform"
        ]
        return HackersPub.JSON(encodableDictionary: value)
    }

    func authorize(_ request: ASAuthorizationRequest) async throws -> ASAuthorization {
        let presentationAnchor = presentationAnchorProvider()
        try requestSlot.reserve(presentationAnchorAvailable: presentationAnchor != nil)
        guard let presentationAnchor else {
            throw PasskeyServiceError.presentationAnchorUnavailable
        }

        let requestID = UUID()
        let activeRequest = requestFactory.makeRequest(
            request: request,
            presentationAnchor: presentationAnchor
        ) { [weak self] in
            self?.finishRequest(id: requestID)
        }
        activeRequestID = requestID
        self.activeRequest = activeRequest
        return try await activeRequest.perform()
    }

    private func finishRequest(id: UUID) {
        guard activeRequestID == id else { return }
        activeRequestID = nil
        activeRequest = nil
        requestSlot.release()
    }

    private static func currentPresentationAnchor() -> ASPresentationAnchor? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        if let keyWindow = windowScenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        return windowScenes.flatMap(\.windows).first
    }
}
