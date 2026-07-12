@testable import HackersPub
import Testing

struct HTMLVisibleTextFallbackTests {
    @Test
    func initialFallbackUsesOnlyVisibleText() {
        let html = """
        <p>Hello <strong>world</strong></p>
        <!-- invisible note -->
        <script>alert('never visible')</script>
        <style>.hidden { display: none; }</style>
        <p>Second&nbsp;line</p>
        """

        #expect(HTMLVisibleTextFallback.text(from: html) == "Hello world Second line")
    }

    @Test
    func initialFallbackNeverTreatsMalformedTagsAsExecutableContent() {
        let html = "Before <script without close"

        #expect(HTMLVisibleTextFallback.text(from: html) == "Before")
    }

    @Test
    func rawTextPrefixesDoNotExposeScriptOrStyleBodiesBeforeTheExactClosingTag() {
        let html = """
        <p>Before</p>
        <script>script hidden</scripture><p>still script hidden</p></ScRiPt >
        <p>Between</p>
        <style>style hidden</stylesheet><p>still style hidden</p></STYLE/>
        <p>After</p>
        """

        #expect(HTMLVisibleTextFallback.text(from: html) == "Before Between After")
    }

    @Test
    func manyOrdinaryTagsUseBoundedUnsafeTagPrefixWork() {
        let visibleParts = (0 ..< 2000).map { "visible-\($0)" }
        let ordinaryHTML = visibleParts.map { "<p>\($0)</p>" }.joined()
        let html = ordinaryHTML + """
        <ScRiPt>hidden script body</sCrIpT>
        <StYlE>hidden style body</sTyLe>
        <p>After</p>
        """

        let result = HTMLVisibleTextFallback.scan(html)

        #expect(result.text == (visibleParts + ["After"]).joined(separator: " "))
        #expect(result.unsafeTagPrefixCharactersInspected <= html.count * 4)
    }
}
