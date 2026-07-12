@testable import HackersPub
import Testing

struct RelayIdentifierTests {
    @Test func canonicalizesUppercaseUUIDs() {
        let uppercase = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        let lowercase = uppercase.lowercased()

        #expect(
            RelayIdentifier.encoded(type: "Note", rawID: uppercase) ==
                RelayIdentifier.encoded(type: "Note", rawID: lowercase)
        )
    }
}
