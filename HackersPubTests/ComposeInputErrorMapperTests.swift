@testable import HackersPub
import Testing

struct ComposeInputErrorMapperTests {
    @Test func mapsContentInputPathToUserFacingContentMessage() {
        #expect(
            ComposeInputErrorMapper.localizationKey(for: "input.content")
                == "compose.error.invalidContent"
        )
    }

    @Test func mapsUnknownInputPathToGenericMessageWithoutExposingThePath() {
        let rawPath = "input.internal.futureField"
        let key = ComposeInputErrorMapper.localizationKey(for: rawPath)

        #expect(key == "compose.error.invalidInput")
        #expect(!key.contains(rawPath))
    }
}
