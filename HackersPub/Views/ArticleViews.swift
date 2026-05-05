import Foundation
import SwiftUI
@preconcurrency import Apollo

struct ArticleTOCItem: Identifiable, Hashable {
    let id: String
    let title: String
    let level: Int
    let children: [ArticleTOCItem]
}

enum ArticleTOCParser {
    static func parse(_ json: HackersPub.JSON) -> [ArticleTOCItem] {
        if let root = normalize(json.value) as? [[String: Any]] {
            return root.compactMap(parseItem)
        }
        return []
    }

    static func parse(_ json: String) -> [ArticleTOCItem] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return root.compactMap(parseItem)
    }

    private static func normalize(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues(normalize)
        }
        if let dictionary = value as? [AnyHashable: Any] {
            let pairs: [(String, Any)] = dictionary.map { key, value in
                (String(describing: key.base), normalize(value))
            }
            return Dictionary<String, Any>(uniqueKeysWithValues: pairs)
        }
        if let array = value as? [Any] {
            return array.map(normalize)
        }
        return value
    }

    private static func parseItem(_ value: [String: Any]) -> ArticleTOCItem? {
        guard let id = value["id"] as? String,
              let title = value["title"] as? String else {
            return nil
        }
        let level = value["level"] as? Int ?? 1
        let children = (value["children"] as? [[String: Any]] ?? []).compactMap(parseItem)
        return ArticleTOCItem(id: id, title: title, level: level, children: children)
    }
}

func htmlToMarkdownish(_ html: String) -> String {
    do {
        return try HTMLToMarkdownConverter.convert(html)
    } catch {
        return html
    }
}

private enum HTMLToMarkdownConverter {
    private struct ListContext {
        enum Kind {
            case unordered
            case ordered(next: Int)
        }

        var kind: Kind
    }

    private struct LinkContext {
        let destination: String
        let startIndex: String.Index
    }

    static func convert(_ html: String) throws -> String {
        let tokens = try HTMLTokenizer.tokenize(html)
        var output = ""
        var listStack: [ListContext] = []
        var linkStack: [LinkContext] = []
        var inlineMarkers: [String: [String]] = [:]
        var isInsidePre = false

        for token in tokens {
            switch token {
            case let .text(value):
                appendText(value, to: &output, preservingWhitespace: isInsidePre)
            case let .entity(_, decoded):
                appendText(decoded, to: &output, preservingWhitespace: isInsidePre)
            case let .openTag(raw, name):
                let tag = name.lowercased()
                switch tag {
                case "h1", "h2", "h3", "h4", "h5", "h6":
                    ensureBlankLine(in: &output)
                    output += String(repeating: "#", count: headingLevel(for: tag)) + " "
                case "p", "div", "section", "article":
                    ensureBlankLine(in: &output)
                case "br":
                    output += "  \n"
                case "ul":
                    ensureBlankLine(in: &output)
                    listStack.append(ListContext(kind: .unordered))
                case "ol":
                    ensureBlankLine(in: &output)
                    listStack.append(ListContext(kind: .ordered(next: startValue(from: raw))))
                case "li":
                    ensureLineStart(in: &output)
                    let indent = String(repeating: "  ", count: max(0, listStack.count - 1))
                    output += indent + marker(for: &listStack)
                case "blockquote":
                    ensureBlankLine(in: &output)
                    output += "> "
                case "pre":
                    ensureBlankLine(in: &output)
                    output += "```\n"
                    isInsidePre = true
                case "code":
                    if !isInsidePre { pushInline("`", tag: tag, stack: &inlineMarkers, output: &output) }
                case "strong", "b":
                    pushInline("**", tag: tag, stack: &inlineMarkers, output: &output)
                case "em", "i":
                    pushInline("*", tag: tag, stack: &inlineMarkers, output: &output)
                case "a":
                    linkStack.append(LinkContext(destination: attribute("href", in: raw) ?? "", startIndex: output.endIndex))
                case "img":
                    appendImage(raw, to: &output)
                default:
                    break
                }
            case let .closeTag(_, name):
                let tag = name.lowercased()
                switch tag {
                case "h1", "h2", "h3", "h4", "h5", "h6", "p", "div", "section", "article":
                    ensureBlankLine(in: &output)
                case "li":
                    ensureLineStart(in: &output)
                case "ul", "ol":
                    if !listStack.isEmpty { listStack.removeLast() }
                    ensureBlankLine(in: &output)
                case "blockquote":
                    ensureBlankLine(in: &output)
                case "pre":
                    if !output.hasSuffix("\n") { output += "\n" }
                    output += "```\n\n"
                    isInsidePre = false
                case "code":
                    if !isInsidePre { popInline(tag: tag, stack: &inlineMarkers, output: &output) }
                case "strong", "b", "em", "i":
                    popInline(tag: tag, stack: &inlineMarkers, output: &output)
                case "a":
                    closeLink(stack: &linkStack, output: &output)
                default:
                    break
                }
            case let .voidTag(raw, name):
                let tag = name.lowercased()
                if tag == "br" {
                    output += "  \n"
                } else if tag == "img" {
                    appendImage(raw, to: &output)
                }
            case .unsafeContent:
                break
            }
        }

        return normalizeMarkdown(output)
    }

    private static func appendText(_ text: String, to output: inout String, preservingWhitespace: Bool) {
        if preservingWhitespace {
            output += text
            return
        }
        let normalized = text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if output.last?.isWhitespace == false, normalized.first?.isWhitespace == false {
            output += " "
        }
        output += normalized
    }

    private static func headingLevel(for tag: String) -> Int {
        Int(tag.dropFirst()) ?? 1
    }

    private static func marker(for listStack: inout [ListContext]) -> String {
        guard let last = listStack.indices.last else { return "- " }
        switch listStack[last].kind {
        case .unordered:
            return "- "
        case .ordered(let next):
            listStack[last].kind = .ordered(next: next + 1)
            return "\(next). "
        }
    }

    private static func startValue(from raw: String) -> Int {
        guard let value = attribute("start", in: raw), let parsed = Int(value) else { return 1 }
        return max(1, parsed)
    }

    private static func pushInline(
        _ marker: String,
        tag: String,
        stack: inout [String: [String]],
        output: inout String
    ) {
        output += marker
        stack[tag, default: []].append(marker)
    }

    private static func popInline(tag: String, stack: inout [String: [String]], output: inout String) {
        guard var markers = stack[tag], let marker = markers.popLast() else { return }
        stack[tag] = markers
        output += marker
    }

    private static func closeLink(stack: inout [LinkContext], output: inout String) {
        guard let link = stack.popLast(), !link.destination.isEmpty else { return }
        let label = output[link.startIndex..<output.endIndex]
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        output.insert("[", at: link.startIndex)
        output += "](\(link.destination))"
    }

    private static func appendImage(_ raw: String, to output: inout String) {
        guard let src = attribute("src", in: raw), !src.isEmpty else { return }
        let alt = attribute("alt", in: raw) ?? ""
        output += "![\(alt)](\(src))"
    }

    private static func attribute(_ name: String, in raw: String) -> String? {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*(['"])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              let valueRange = Range(match.range(at: 2), in: raw) else {
            return nil
        }
        return String(raw[valueRange])
    }

    private static func ensureLineStart(in output: inout String) {
        if output.isEmpty || output.hasSuffix("\n") { return }
        output += "\n"
    }

    private static func ensureBlankLine(in output: inout String) {
        let trimmedEnd = output.trimmingCharacters(in: .whitespacesAndNewlines)
        output = trimmedEnd
        if !output.isEmpty { output += "\n\n" }
    }

    private static func normalizeMarkdown(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #" *\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ArticleSummaryCard<P: PostProtocol>: View {
    let post: P
    let onRead: () -> Void
    @Environment(ExternalURLRouter.self) private var externalURLRouter

    var body: some View {
        Button(action: onRead) {
            VStack(alignment: .leading, spacing: 10) {
                if let name = post.name {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(post.summary?.nilIfBlank ?? post.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "doc.richtext")
                    Text(NSLocalizedString("article.read", comment: "Read article action"))
                    Spacer()
                    if let url = post.resolvedShareURL, url.absoluteString != post.iri {
                        Image(systemName: "safari")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onRead()
            } label: {
                Label(NSLocalizedString("article.read", comment: "Read article action"), systemImage: "doc.text")
            }

            if let url = post.resolvedShareURL {
                Button {
                    externalURLRouter.open(url)
                } label: {
                    Label(NSLocalizedString("article.readOnWeb", comment: "Read on web action"), systemImage: "safari")
                }

                ShareLink(item: url) {
                    Label(NSLocalizedString("sneakpeek.action.sharePost", comment: "Share post"), systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

struct ArticleTOCPanel: View {
    let items: [ArticleTOCItem]
    let onSelect: (String) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("article.toc", comment: "Article table of contents"))
                    .font(.headline)

                ForEach(flatten(items)) { item in
                    Button {
                        onSelect(item.id)
                    } label: {
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .lineLimit(2)
                            .padding(.leading, CGFloat(max(0, item.level - 1)) * 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func flatten(_ items: [ArticleTOCItem]) -> [ArticleTOCItem] {
        items.flatMap { [$0] + flatten($0.children) }
    }
}

struct ArticleContentPane: View {
    let html: String
    let toc: [ArticleTOCItem]
    let media: [MediaItem]
    let onAnchorSelected: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArticleTOCPanel(items: toc, onSelect: onAnchorSelected)

            ForEach(Array(ArticleHTMLSectioner.sections(html: html, toc: toc).enumerated()), id: \.element.id) { index, section in
                ArticleContentDocumentView(html: section.html, media: index == 0 ? media : [])
                    .id(section.id)
            }
        }
    }
}

struct ArticleHTMLSection: Identifiable {
    let id: String
    let html: String
}

enum ArticleHTMLSectioner {
    private static let topID = "article-top"

    static func sections(html: String, toc: [ArticleTOCItem]) -> [ArticleHTMLSection] {
        let anchorIDs = Set(flatten(toc).map(\.id))
        guard !anchorIDs.isEmpty else {
            return [ArticleHTMLSection(id: topID, html: html)]
        }

        let pattern = #"<h([1-6])\b[^>]*\bid\s*=\s*["']([^"']+)["'][^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return [ArticleHTMLSection(id: topID, html: html)]
        }

        let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: fullRange).compactMap { match -> (id: String, range: Range<String.Index>)? in
            guard match.numberOfRanges >= 3,
                  let idRange = Range(match.range(at: 2), in: html),
                  let headingRange = Range(match.range(at: 0), in: html) else {
                return nil
            }
            let id = String(html[idRange])
            return anchorIDs.contains(id) ? (id, headingRange) : nil
        }

        guard !matches.isEmpty else {
            return [ArticleHTMLSection(id: topID, html: html)]
        }

        var sections: [ArticleHTMLSection] = []
        let firstHeadingStart = matches[0].range.lowerBound
        if html.startIndex < firstHeadingStart {
            let preamble = String(html[html.startIndex..<firstHeadingStart]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !preamble.isEmpty {
                sections.append(ArticleHTMLSection(id: topID, html: preamble))
            }
        }

        for (index, match) in matches.enumerated() {
            let sectionStart = match.range.lowerBound
            let sectionEnd = index + 1 < matches.count ? matches[index + 1].range.lowerBound : html.endIndex
            let sectionHTML = String(html[sectionStart..<sectionEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sectionHTML.isEmpty {
                sections.append(ArticleHTMLSection(id: match.id, html: sectionHTML))
            }
        }

        return sections.isEmpty ? [ArticleHTMLSection(id: topID, html: html)] : sections
    }

    private static func flatten(_ items: [ArticleTOCItem]) -> [ArticleTOCItem] {
        items.flatMap { [$0] + flatten($0.children) }
    }
}

struct ArticleDraftListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [HackersPub.ArticleDraftsQuery.Data.Viewer.ArticleDrafts.Edge.Node] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var draftToDelete: HackersPub.ArticleDraftsQuery.Data.Viewer.ArticleDrafts.Edge.Node?
    @State private var editingDraftId: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
                } else if drafts.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("article.drafts.empty", comment: "No article drafts"),
                        systemImage: "doc"
                    )
                } else {
                    List {
                        ForEach(drafts, id: \.id) { draft in
                            Button {
                                editingDraftId = draft.id
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(draft.title.nilIfBlank ?? NSLocalizedString("article.untitled", comment: "Untitled article"))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(DateFormatHelper.fullDateTime(from: draft.updated))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !draft.tags.isEmpty {
                                        Text(draft.tags.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    draftToDelete = draft
                                } label: {
                                    Label(NSLocalizedString("delete.confirm.action", comment: "Delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("article.drafts", comment: "Article drafts title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel"), action: { dismiss() })
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingDraftId = ""
                    } label: {
                        Label(NSLocalizedString("article.new", comment: "New article"), systemImage: "plus")
                    }
                }
            }
            .task {
                await loadDrafts()
            }
            .refreshable {
                await loadDrafts()
            }
            .alert(
                NSLocalizedString("article.draft.delete.title", comment: "Delete draft title"),
                isPresented: Binding(
                    get: { draftToDelete != nil },
                    set: { if !$0 { draftToDelete = nil } }
                )
            ) {
                Button(NSLocalizedString("delete.confirm.action", comment: "Delete"), role: .destructive) {
                    if let draftToDelete {
                        Task {
                            await deleteDraft(id: draftToDelete.id)
                        }
                    }
                }
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("article.draft.delete.message", comment: "Delete draft confirmation"))
            }
            .sheet(item: Binding(
                get: { editingDraftId.map(ArticleDraftEditorTarget.init(id:)) },
                set: { editingDraftId = $0?.id }
            )) { target in
                ArticleEditorView(draftId: target.id.isEmpty ? nil : target.id) {
                    editingDraftId = nil
                    Task {
                        await loadDrafts()
                    }
                }
            }
        }
    }

    private func loadDrafts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(query: HackersPub.ArticleDraftsQuery(), cachePolicy: .networkOnly)
            drafts = response.data?.viewer?.articleDrafts.edges.map { $0.node } ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteDraft(id: String) async {
        do {
            let response = try await apolloClient.perform(mutation: HackersPub.DeleteArticleDraftMutation(id: id))
            if response.data?.deleteArticleDraft.asDeleteArticleDraftPayload != nil {
                drafts.removeAll { $0.id == id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        draftToDelete = nil
    }
}

private struct ArticleDraftEditorTarget: Identifiable {
    let id: String
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
