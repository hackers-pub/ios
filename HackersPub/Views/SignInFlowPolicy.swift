import Foundation

enum SignInVerificationAction: Equatable {
    case verify(String)
    case restart
}

enum SignInFlowPolicy {
    static func trimmedUsername(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canRequestSignInLink(username: String) -> Bool {
        !trimmedUsername(username).isEmpty
    }

    static func verificationAction(loginToken: String?) -> SignInVerificationAction {
        guard let loginToken, !loginToken.isEmpty else {
            return .restart
        }
        return .verify(loginToken)
    }
}
