import ApolloAPI
@testable import HackersPub
import Testing

struct PasskeyAuthenticationPayloadTests {
    @Test func rejectsEmptyAuthenticationChallenge() {
        #expect(throws: PasskeyServiceError.invalidChallenge) {
            try PasskeyAuthenticationOptions(
                json: authenticationOptionsJSON(challenge: "")
            )
        }
    }

    @Test func rejectsBlankAuthenticationRelyingPartyID() {
        #expect(throws: PasskeyServiceError.invalidOptions) {
            try PasskeyAuthenticationOptions(
                json: authenticationOptionsJSON(relyingPartyID: " \n\t ")
            )
        }
    }

    @Test func rejectsMalformedAllowedCredentialIDs() {
        let credential: ApolloAPI.JSONEncodableDictionary = [
            "id": "",
            "type": "public-key"
        ]

        #expect(throws: PasskeyServiceError.invalidOptions) {
            try PasskeyAuthenticationOptions(
                json: authenticationOptionsJSON(allowedCredentials: [credential])
            )
        }
    }

    private func authenticationOptionsJSON(
        challenge: String = "Y2hhbGxlbmdl",
        relyingPartyID: String = "hackers.pub",
        allowedCredentials: [ApolloAPI.JSONEncodableDictionary]? = nil
    ) -> HackersPub.JSON {
        var options: ApolloAPI.JSONEncodableDictionary = [
            "challenge": challenge,
            "rpId": relyingPartyID
        ]
        if let allowedCredentials {
            options["allowCredentials"] = allowedCredentials
        }
        return HackersPub.JSON(encodableDictionary: options)
    }
}
