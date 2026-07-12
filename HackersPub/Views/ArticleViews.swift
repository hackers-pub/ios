@preconcurrency import Apollo
import Foundation
import SwiftUI

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
              let root = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
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
            return [String: Any](uniqueKeysWithValues: pairs)
        }
        if let array = value as? [Any] {
            return array.map(normalize)
        }
        return value
    }

    private static func parseItem(_ value: [String: Any]) -> ArticleTOCItem? {
        guard let id = value["id"] as? String,
              let title = value["title"] as? String
        else {
            return nil
        }
        let level = value["level"] as? Int ?? 1
        let children = (value["children"] as? [[String: Any]] ?? []).compactMap(parseItem)
        return ArticleTOCItem(id: id, title: title, level: level, children: children)
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

enum ArticleDraftListFailureRoute: Equatable {
    case initialLoad
    case retainedList

    static func resolve(hasLoadedDrafts: Bool) -> Self {
        hasLoadedDrafts ? .retainedList : .initialLoad
    }
}

enum ArticleDraftDeleteOutcome: Equatable {
    case deleted
    case failed

    static func resolve(hasResponseErrors: Bool, hasDeletePayload: Bool) -> Self {
        hasResponseErrors || !hasDeletePayload ? .failed : .deleted
    }
}

struct ArticleDraftListItem: Identifiable, Equatable {
    let id: String
    let title: String
    let tags: [String]
    let updated: String
}

enum ArticleDraftListLoadIntent: Equatable {
    case automatic
    case explicitRefresh
}

enum ArticleDraftListLoadResponse: Equatable {
    case success([ArticleDraftListItem])
    case failed
}

enum ArticleDraftListDeleteResponse: Equatable {
    case deleted
    case failed
}

enum ArticleEditorTarget: Identifiable, Equatable {
    case new
    case draft(String)

    var id: String {
        switch self {
        case .new:
            "new"
        case let .draft(draftID):
            "draft-\(draftID)"
        }
    }

    var draftID: String? {
        switch self {
        case .new:
            nil
        case let .draft(draftID):
            draftID
        }
    }
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

        let fullRange = NSRange(html.startIndex ..< html.endIndex, in: html)
        let matches = regex.matches(in: html, range: fullRange).compactMap { match -> (id: String, range: Range<String.Index>)? in
            guard match.numberOfRanges >= 3,
                  let idRange = Range(match.range(at: 2), in: html),
                  let headingRange = Range(match.range(at: 0), in: html)
            else {
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
            let preamble = String(
                html[html.startIndex ..< firstHeadingStart]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            if !preamble.isEmpty {
                sections.append(ArticleHTMLSection(id: topID, html: preamble))
            }
        }

        for (index, match) in matches.enumerated() {
            let sectionStart = match.range.lowerBound
            let sectionEnd = index + 1 < matches.count ? matches[index + 1].range.lowerBound : html.endIndex
            let sectionHTML = String(html[sectionStart ..< sectionEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
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

enum ArticleDraftListActionFailure: Identifiable, Equatable {
    case reload
    case delete(id: String)

    var id: String {
        switch self {
        case .reload:
            "reload"
        case let .delete(id):
            "delete-\(id)"
        }
    }

    var message: String {
        switch self {
        case .reload:
            NSLocalizedString("article.drafts.loadFailed", comment: "Article drafts load failed")
        case .delete:
            NSLocalizedString("article.draft.deleteFailed", comment: "Article draft delete failed")
        }
    }
}

struct ArticleDraftPage<Item> {
    let items: [Item]
    let hasNextPage: Bool
    let endCursor: String?
}

typealias ArticleDraftPageLoader<Item> = @MainActor (String?) async throws -> ArticleDraftPage<Item>

struct ArticleDraftPaginationState<Item> {
    private let nodeID: (Item) -> String
    private(set) var items: [Item] = []
    private(set) var hasNextPage = false
    private(set) var endCursor: String?
    private(set) var isLoadingMore = false
    private(set) var loadMoreErrorMessage: String?

    init(nodeID: @escaping (Item) -> String) {
        self.nodeID = nodeID
    }

    mutating func replace(with page: ArticleDraftPage<Item>) {
        items = deduplicated(page.items)
        hasNextPage = page.hasNextPage
        endCursor = page.endCursor
        isLoadingMore = false
        loadMoreErrorMessage = nil
    }

    mutating func beginLoadingMore() -> String? {
        guard hasNextPage, let endCursor, !isLoadingMore else { return nil }
        isLoadingMore = true
        loadMoreErrorMessage = nil
        return endCursor
    }

    mutating func append(_ page: ArticleDraftPage<Item>) {
        items = deduplicated(items + page.items)
        hasNextPage = page.hasNextPage
        endCursor = page.endCursor
        isLoadingMore = false
        loadMoreErrorMessage = nil
    }

    mutating func recordLoadMoreFailure(_ message: String) {
        isLoadingMore = false
        loadMoreErrorMessage = message
    }

    mutating func cancelLoadingMore() {
        isLoadingMore = false
        loadMoreErrorMessage = nil
    }

    mutating func remove(id: String) {
        items.removeAll { nodeID($0) == id }
    }

    private func deduplicated(_ candidates: [Item]) -> [Item] {
        var seen = Set<String>()
        return candidates.filter { seen.insert(nodeID($0)).inserted }
    }
}

private enum ArticleDraftListError: LocalizedError {
    case graphQL(String)
    case missingConnection

    var errorDescription: String? {
        switch self {
        case let .graphQL(message):
            message
        case .missingConnection:
            NSLocalizedString("error.loadFailed.title", comment: "Article drafts load failure")
        }
    }
}

private enum ArticleDraftListRequestError: LocalizedError {
    case failed

    var errorDescription: String? {
        NSLocalizedString("article.drafts.loadFailed", comment: "Article drafts load failed")
    }
}

@Observable
@MainActor
final class ArticleDraftListLoader<Item> {
    private let nodeID: (Item) -> String
    private let pageLoader: ArticleDraftPageLoader<Item>?
    private var pagination: ArticleDraftPaginationState<Item>
    private var requestGeneration = 0

    @ObservationIgnored
    private var refreshTask: Task<ArticleDraftPage<Item>, Error>?
    @ObservationIgnored
    private var deletionTombstones: Set<String> = []

    private(set) var isLoading = true
    private(set) var errorMessage: String?
    private(set) var initialLoadError: String?
    private(set) var actionFailure: ArticleDraftListActionFailure?
    private(set) var deletingDraftIDs: Set<String> = []

    var items: [Item] {
        pagination.items
    }

    var drafts: [Item] {
        pagination.items
    }

    var hasNextPage: Bool {
        pagination.hasNextPage
    }

    var endCursor: String? {
        pagination.endCursor
    }

    var isLoadingMore: Bool {
        pagination.isLoadingMore
    }

    var loadMoreErrorMessage: String? {
        pagination.loadMoreErrorMessage
    }

    init(
        nodeID: @escaping (Item) -> String,
        pageLoader: ArticleDraftPageLoader<Item>? = nil
    ) {
        self.nodeID = nodeID
        self.pageLoader = pageLoader
        pagination = ArticleDraftPaginationState(nodeID: nodeID)
    }

    func refresh(intent: ArticleDraftListLoadIntent = .automatic) async {
        guard let pageLoader else { return }
        let task: Task<ArticleDraftPage<Item>, Error> = Task {
            try await pageLoader(nil)
        }
        await performRefresh(intent: intent, task: task)
    }

    func loadMore() async {
        guard let pageLoader, let cursor = pagination.beginLoadingMore() else { return }
        let generation = requestGeneration

        do {
            let page = try await pageLoader(cursor)
            guard generation == requestGeneration, !Task.isCancelled else { return }
            pagination.append(filtered(page))
        } catch is CancellationError {
            guard generation == requestGeneration else { return }
            pagination.cancelLoadingMore()
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            pagination.recordLoadMoreFailure(error.localizedDescription)
        }
    }

    func remove(id: String) {
        deletionTombstones.insert(id)
        pagination.remove(id: id)
    }

    func hasDeletionTombstone(for id: String) -> Bool {
        deletionTombstones.contains(id)
    }

    func isDeleting(id: String) -> Bool {
        deletingDraftIDs.contains(id)
    }

    func dismissActionFailure() {
        actionFailure = nil
    }

    func delete(
        id: String,
        request: @escaping @MainActor () async -> ArticleDraftListDeleteResponse
    ) async {
        guard !deletingDraftIDs.contains(id) else { return }
        deletingDraftIDs.insert(id)

        let task = Task { await request() }
        let response = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }

        deletingDraftIDs.remove(id)
        guard !Task.isCancelled else { return }

        switch response {
        case .deleted:
            remove(id: id)
            actionFailure = nil
        case .failed:
            actionFailure = .delete(id: id)
        }
    }

    private func performRefresh(
        intent: ArticleDraftListLoadIntent,
        task: Task<ArticleDraftPage<Item>, Error>
    ) async {
        let failureRoute = ArticleDraftListFailureRoute.resolve(hasLoadedDrafts: !items.isEmpty)
        requestGeneration &+= 1
        let generation = requestGeneration
        refreshTask?.cancel()
        refreshTask = task

        if items.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        if failureRoute == .initialLoad {
            initialLoadError = nil
        }
        pagination.cancelLoadingMore()

        do {
            let page = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            guard generation == requestGeneration, !Task.isCancelled else { return }

            refreshTask = nil
            isLoading = false
            if intent == .explicitRefresh {
                deletionTombstones.formIntersection(Set(page.items.map(nodeID)))
            }
            pagination.replace(with: filtered(page))
            initialLoadError = nil
            actionFailure = nil
            errorMessage = nil
        } catch is CancellationError {
            guard generation == requestGeneration else { return }
            refreshTask = nil
            isLoading = false
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            refreshTask = nil
            isLoading = false
            errorMessage = error.localizedDescription
            recordLoadFailure(for: failureRoute)
        }
    }

    private func filtered(_ page: ArticleDraftPage<Item>) -> ArticleDraftPage<Item> {
        ArticleDraftPage(
            items: page.items.filter { !deletionTombstones.contains(nodeID($0)) },
            hasNextPage: page.hasNextPage,
            endCursor: page.endCursor
        )
    }

    private func recordLoadFailure(for route: ArticleDraftListFailureRoute) {
        switch route {
        case .initialLoad:
            initialLoadError = NSLocalizedString("article.drafts.loadFailed", comment: "Article drafts load failed")
        case .retainedList:
            actionFailure = .reload
        }
    }
}

extension ArticleDraftListLoader where Item == ArticleDraftListItem {
    func load(
        intent: ArticleDraftListLoadIntent,
        request: @escaping @MainActor () async -> ArticleDraftListLoadResponse
    ) async {
        let task: Task<ArticleDraftPage<ArticleDraftListItem>, Error> = Task {
            switch await request() {
            case let .success(items):
                ArticleDraftPage(items: items, hasNextPage: false, endCursor: nil)
            case .failed:
                throw ArticleDraftListRequestError.failed
            }
        }
        await performRefresh(intent: intent, task: task)
    }
}

struct ArticleDraftListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var loader: ArticleDraftListLoader<ArticleDraftListItem>
    @State private var draftToDelete: ArticleDraftListItem?
    @State private var editorTarget: ArticleEditorTarget?

    init() {
        _loader = State(initialValue: ArticleDraftListLoader(nodeID: \.id) { cursor in
            try await Self.fetchDraftPage(after: cursor)
        })
    }

    private var drafts: [ArticleDraftListItem] {
        loader.items
    }

    var body: some View {
        NavigationStack {
            Group {
                if loader.isLoading && drafts.isEmpty {
                    ProgressView()
                } else if drafts.isEmpty, let initialLoadError = loader.initialLoadError {
                    VStack(spacing: 16) {
                        ContentUnavailableView(initialLoadError, systemImage: "exclamationmark.triangle")

                        Button(NSLocalizedString("common.retry", comment: "Retry")) {
                            Task {
                                await loadDrafts(intent: .automatic)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if drafts.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("article.drafts.empty", comment: "No article drafts"),
                        systemImage: "doc"
                    )
                } else {
                    List {
                        ForEach(drafts) { draft in
                            Button {
                                editorTarget = .draft(draft.id)
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
                            .disabled(loader.isDeleting(id: draft.id))
                            .onAppear {
                                guard shouldLoadMore(afterAppearing: draft) else { return }
                                Task {
                                    await loadMoreDrafts()
                                }
                            }
                        }

                        if loader.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }

                        if let loadMoreErrorMessage = loader.loadMoreErrorMessage {
                            InlineLoadFailureView(message: loadMoreErrorMessage) {
                                Task {
                                    await loadMoreDrafts()
                                }
                            }
                            .listRowSeparator(.hidden)
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
                        editorTarget = .new
                    } label: {
                        Label(NSLocalizedString("article.new", comment: "New article"), systemImage: "plus")
                    }
                }
            }
            .task {
                await loadDrafts(intent: .automatic)
            }
            .refreshable {
                await loadDrafts(intent: .explicitRefresh)
            }
            .alert(
                NSLocalizedString("article.draft.delete.title", comment: "Delete draft title"),
                isPresented: Binding(
                    get: { draftToDelete != nil },
                    set: {
                        if !$0 {
                            draftToDelete = nil
                        }
                    }
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
            .alert(
                NSLocalizedString("compose.error.title", comment: "Error"),
                isPresented: Binding(
                    get: { loader.actionFailure != nil },
                    set: {
                        if !$0 {
                            loader.dismissActionFailure()
                        }
                    }
                )
            ) {
                if let actionFailure = loader.actionFailure {
                    Button(NSLocalizedString("common.retry", comment: "Retry")) {
                        retry(actionFailure)
                    }
                }
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(loader.actionFailure?.message ?? "")
            }
            .sheet(item: $editorTarget) { target in
                ArticleEditorView(draftId: target.draftID) {
                    editorTarget = nil
                    Task {
                        await loadDrafts(intent: .automatic)
                    }
                }
            }
        }
    }

    private static let draftPageSize: Int32 = 50

    private func shouldLoadMore(afterAppearing draft: ArticleDraftListItem) -> Bool {
        guard loader.hasNextPage,
              !loader.isLoadingMore,
              loader.loadMoreErrorMessage == nil
        else {
            return false
        }
        return draft.id == drafts.last?.id
    }

    private func loadDrafts(intent: ArticleDraftListLoadIntent) async {
        await loader.refresh(intent: intent)
    }

    private func loadMoreDrafts() async {
        await loader.loadMore()
    }

    private static func fetchDraftPage(after cursor: String?) async throws -> ArticleDraftPage<ArticleDraftListItem> {
        let response = try await apolloClient.fetch(
            query: HackersPub.ArticleDraftsQuery(
                after: cursor.map(GraphQLNullable.some) ?? .none,
                first: Self.draftPageSize
            ),
            cachePolicy: .networkOnly
        )
        if let error = response.errors?.first {
            throw ArticleDraftListError.graphQL(
                error.message ?? NSLocalizedString("error.loadFailed.title", comment: "Article drafts load failure")
            )
        }
        guard let connection = response.data?.viewer?.articleDrafts else {
            throw ArticleDraftListError.missingConnection
        }

        return ArticleDraftPage(
            items: connection.edges.map {
                ArticleDraftListItem(
                    id: $0.node.id,
                    title: $0.node.title,
                    tags: $0.node.tags,
                    updated: $0.node.updated
                )
            },
            hasNextPage: connection.pageInfo.hasNextPage,
            endCursor: connection.pageInfo.endCursor
        )
    }

    private func deleteDraft(id: String) async {
        defer { draftToDelete = nil }

        await loader.delete(id: id) {
            do {
                let response = try await apolloClient.perform(
                    mutation: HackersPub.DeleteArticleDraftMutation(id: id)
                )
                switch ArticleDraftDeleteOutcome.resolve(
                    hasResponseErrors: response.errors?.isEmpty == false,
                    hasDeletePayload: response.data?.deleteArticleDraft.asDeleteArticleDraftPayload != nil
                ) {
                case .deleted:
                    return .deleted
                case .failed:
                    return .failed
                }
            } catch {
                return .failed
            }
        }
    }

    private func retry(_ failure: ArticleDraftListActionFailure) {
        Task {
            switch failure {
            case .reload:
                await loadDrafts(intent: .automatic)
            case let .delete(id):
                await deleteDraft(id: id)
            }
        }
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
