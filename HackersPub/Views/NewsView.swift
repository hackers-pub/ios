import Apollo
import Kingfisher
import SwiftUI

private enum NewsSortOption: String, CaseIterable, Identifiable {
    case popular
    case newest
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popular:
            return NSLocalizedString("news.sort.popular", comment: "Popular news sort")
        case .newest:
            return NSLocalizedString("news.sort.newest", comment: "Newest news sort")
        case .allTime:
            return NSLocalizedString("news.sort.allTime", comment: "All-time news sort")
        }
    }

    var order: GraphQLEnum<HackersPub.NewsOrder> {
        switch self {
        case .popular:
            return .case(.popular)
        case .newest:
            return .case(.newest)
        case .allTime:
            return .case(.allTime)
        }
    }
}

private struct NewsComposeSeed: Identifiable {
    let id = UUID()
    let content: String
}

struct NewsView: View {
    @State private var edges: [HackersPub.NewsStoriesQuery.Data.NewsStories.Edge] = []
    @State private var selectedSort: NewsSortOption = .popular
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoadedInitial = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var isModerator = false
    @State private var showingSettings = false
    @State private var showingAdmin = false
    @State private var composeSeed: NewsComposeSeed?

    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        NavigationStack(path: navigationCoordinator.pathBinding(for: .news)) {
            Group {
                if isLoading && edges.isEmpty {
                    ProgressView(NSLocalizedString("timeline.loading", comment: "Loading indicator"))
                } else if let errorMessage, edges.isEmpty {
                    LoadFailureView(message: errorMessage) {
                        Task {
                            await fetchStories(reset: true)
                        }
                    }
                } else if edges.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("news.empty.title", comment: "No news stories title"),
                        systemImage: "newspaper",
                        description: Text(NSLocalizedString("news.empty.description", comment: "No news stories description"))
                    )
                } else {
                    newsList
                }
            }
            .navigationTitle(NSLocalizedString("nav.news", comment: "News navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if authManager.isAuthenticated {
                    ToolbarItem(placement: .topBarLeading) {
                        ViewerProfileButton()
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Label(NSLocalizedString("common.settings", comment: "Settings button"), systemImage: "gear")
                        }
                    }

                    if isModerator {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingAdmin = true
                            } label: {
                                Label(NSLocalizedString("news.admin.title", comment: "News admin button"), systemImage: "shield")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAdmin) {
                NewsAdminView {
                    Task {
                        await fetchStories(reset: true)
                    }
                }
            }
            .sheet(item: $composeSeed) { seed in
                ComposeView(initialContent: seed.content)
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .profile(let handle):
                    ActorProfileViewWrapper(handle: handle)
                case .post(let id):
                    PostDetailView(postId: id)
                case .newsStory(let id):
                    NewsStoryDetailView(storyId: id)
                }
            }
            .task {
                guard !hasLoadedInitial else { return }
                hasLoadedInitial = true
                await fetchStories(reset: true)
            }
            .onChange(of: selectedSort) { _, _ in
                Task {
                    await fetchStories(reset: true)
                }
            }
        }
    }

    private var newsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                sortPicker
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                ForEach(edges, id: \.node.id) { edge in
                    NewsStoryCardView(
                        story: edge.node,
                        isModerator: isModerator,
                        onShare: authManager.isAuthenticated ? {
                            composeSeed = NewsComposeSeed(content: "\(edge.node.url)\n\n")
                        } : nil,
                        onSetPenalty: { penalty in
                            Task {
                                await setPenalty(penalty, for: edge.node.uuid)
                            }
                        }
                    )
                    .id(edge.node.id)
                    .onAppear {
                        if edge.node.id == edges.last?.node.id && hasNextPage && !isLoading {
                            Task {
                                await loadMore()
                            }
                        }
                    }

                    Divider()
                }

                if isLoading && !edges.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }

                if let errorMessage, !edges.isEmpty {
                    InlineLoadFailureView(message: errorMessage) {
                        Task {
                            await fetchStories(reset: true)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .refreshable {
            await fetchStories(reset: true)
        }
    }

    private var sortPicker: some View {
        Picker(NSLocalizedString("news.sort", comment: "News sort picker"), selection: $selectedSort) {
            ForEach(NewsSortOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private func fetchStories(reset: Bool) async {
        if reset {
            endCursor = nil
            hasNextPage = false
        }
        if edges.isEmpty || reset {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.NewsStoriesQuery(order: .some(selectedSort.order), after: nil, first: 25),
                cachePolicy: .networkOnly
            )
            let connection = response.data?.newsStories
            edges = connection?.edges ?? []
            hasNextPage = connection?.pageInfo.hasNextPage ?? false
            endCursor = connection?.pageInfo.endCursor
            isModerator = response.data?.viewer?.moderator ?? false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading news stories: \(error)")
        }
    }

    private func loadMore() async {
        guard hasNextPage, let endCursor, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.NewsStoriesQuery(order: .some(selectedSort.order), after: .some(endCursor), first: 25),
                cachePolicy: .networkOnly
            )
            let connection = response.data?.newsStories
            let existingIDs = Set(edges.map(\.node.id))
            edges.append(contentsOf: (connection?.edges ?? []).filter { !existingIDs.contains($0.node.id) })
            hasNextPage = connection?.pageInfo.hasNextPage ?? false
            self.endCursor = connection?.pageInfo.endCursor
            isModerator = response.data?.viewer?.moderator ?? isModerator
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading more news stories: \(error)")
        }
    }

    private func setPenalty(_ penalty: HackersPub.NewsPenalty, for storyId: String) async {
        do {
            let response = try await apolloClient.perform(
                mutation: HackersPub.SetNewsScorePenaltyMutation(id: storyId, penalty: .case(penalty))
            )
            guard response.data?.setNewsScorePenalty?.asPostLink != nil else {
                errorMessage = NSLocalizedString("news.moderation.failed", comment: "News moderation failed")
                return
            }
            await fetchStories(reset: true)
        } catch {
            errorMessage = error.localizedDescription
            print("Error setting news penalty: \(error)")
        }
    }
}

private struct NewsStoryCardView: View {
    let story: HackersPub.NewsStoriesQuery.Data.NewsStories.Edge.Node
    let isModerator: Bool
    let onShare: (() -> Void)?
    let onSetPenalty: (HackersPub.NewsPenalty) -> Void

    @Environment(ExternalURLRouter.self) private var externalURLRouter

    private var displayTitle: String {
        story.title?.nilIfBlank ?? host
    }

    private var host: String {
        NewsURLFormatter.host(from: story.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Button {
                        openExternalURL()
                    } label: {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 4) {
                        Text(host)
                        if let siteName = story.siteName?.nilIfBlank, siteName != host {
                            Text("·")
                            Text(siteName)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let description = story.description?.nilIfBlank {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                if let image = story.image, let url = URL(string: image.url) {
                    KFImage(url)
                        .placeholder {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary)
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(image.alt ?? "")
                }
            }

            HStack(spacing: 12) {
                NavigationLink(value: NavigationDestination.newsStory(id: story.uuid)) {
                    Label(
                        String(format: NSLocalizedString("news.opinions.count", comment: "News discussion count"), story.discussionCount),
                        systemImage: "bubble.left.and.bubble.right"
                    )
                }
                .buttonStyle(.borderless)

                if let latestActivityAt = story.latestActivityAt {
                    Text(String(format: NSLocalizedString("news.lastActive", comment: "News last active"), DateFormatHelper.relativeTime(from: latestActivityAt)))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if let onShare {
                    Button(action: onShare) {
                        Label(NSLocalizedString("news.shareLink", comment: "Share news link"), systemImage: "square.and.pencil")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(NSLocalizedString("news.shareLink", comment: "Share news link"))
                }

                if isModerator {
                    NewsModerationMenu(onSetPenalty: onSetPenalty)
                }
            }
            .font(.caption)
        }
        .padding()
        .contentShape(Rectangle())
    }

    private func openExternalURL() {
        guard let url = URL(string: story.url) else { return }
        externalURLRouter.open(url)
    }
}

private struct NewsModerationMenu: View {
    let onSetPenalty: (HackersPub.NewsPenalty) -> Void

    var body: some View {
        Menu {
            Button {
                onSetPenalty(.demote)
            } label: {
                Label(NSLocalizedString("news.moderation.demote", comment: "Demote news story"), systemImage: "arrow.down.forward")
            }

            Button(role: .destructive) {
                onSetPenalty(.bury)
            } label: {
                Label(NSLocalizedString("news.moderation.bury", comment: "Bury news story"), systemImage: "arrow.down.to.line")
            }

            Button {
                onSetPenalty(.none)
            } label: {
                Label(NSLocalizedString("news.moderation.clear", comment: "Clear news moderation penalty"), systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 30, height: 30)
        }
        .accessibilityLabel(NSLocalizedString("news.moderation.title", comment: "Moderate news story"))
    }
}

struct NewsStoryDetailView: View {
    let storyId: String

    @State private var story: HackersPub.NewsStoryDetailQuery.Data.NewsStory?
    @State private var sharingPosts: [HackersPub.NewsStoryDetailQuery.Data.NewsStory.SharingPosts.Edge] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoadedInitial = false
    @State private var hasNextPage = false
    @State private var endCursor: String?
    @State private var composeSeed: NewsComposeSeed?

    @Environment(AuthManager.self) private var authManager
    @Environment(ExternalURLRouter.self) private var externalURLRouter

    var body: some View {
        Group {
            if isLoading && story == nil {
                ProgressView(NSLocalizedString("timeline.loading", comment: "Loading indicator"))
            } else if let errorMessage, story == nil {
                LoadFailureView(message: errorMessage) {
                    Task {
                        await fetchStory(reset: true)
                    }
                }
            } else if story == nil {
                ContentUnavailableView(
                    NSLocalizedString("news.detail.notFound.title", comment: "News story not found title"),
                    systemImage: "newspaper",
                    description: Text(NSLocalizedString("news.detail.notFound.description", comment: "News story not found description"))
                )
            } else {
                detailContent
            }
        }
        .navigationTitle(NSLocalizedString("nav.news", comment: "News navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let story {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if authManager.isAuthenticated {
                        Button {
                            composeSeed = NewsComposeSeed(content: "\(story.url)\n\n")
                        } label: {
                            Label(NSLocalizedString("news.composeLink", comment: "Compose note with news link"), systemImage: "square.and.pencil")
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityLabel(NSLocalizedString("news.composeLink", comment: "Compose note with news link"))
                    }

                    Button {
                        openExternalURL(story.url)
                    } label: {
                        Label(NSLocalizedString("news.openLink", comment: "Open news link"), systemImage: "safari")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel(NSLocalizedString("news.openLink", comment: "Open news link"))
                }
            }
        }
        .sheet(item: $composeSeed) { seed in
            ComposeView(initialContent: seed.content)
        }
        .task {
            guard !hasLoadedInitial else { return }
            hasLoadedInitial = true
            await fetchStory(reset: true)
        }
    }

    private var detailContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let story {
                    NewsStoryHeaderView(story: story)
                    .padding()
                }

                if sharingPosts.isEmpty && !isLoading {
                    ContentUnavailableView(
                        NSLocalizedString("news.discussion.empty.title", comment: "No news discussion title"),
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(NSLocalizedString("news.discussion.empty.description", comment: "No news discussion description"))
                    )
                    .padding(.vertical, 32)
                } else {
                    ForEach(sharingPosts, id: \.node.id) { edge in
                        PostView(
                            post: edge.node,
                            showAuthor: true,
                            enableSneakPeek: true,
                            contentRenderMode: .lightweightText
                        )
                        .padding()
                        .onAppear {
                            if edge.node.id == sharingPosts.last?.node.id && hasNextPage && !isLoading {
                                Task {
                                    await loadMore()
                                }
                            }
                        }

                        Divider()
                    }
                }

                if isLoading && story != nil {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }

                if let errorMessage, story != nil {
                    InlineLoadFailureView(message: errorMessage) {
                        Task {
                            await fetchStory(reset: true)
                        }
                    }
                }
            }
        }
        .refreshable {
            await fetchStory(reset: true)
        }
    }

    private func fetchStory(reset: Bool) async {
        if reset {
            endCursor = nil
            hasNextPage = false
        }
        if story == nil || reset {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.NewsStoryDetailQuery(id: storyId, after: nil, first: 20),
                cachePolicy: .networkOnly
            )
            story = response.data?.newsStory
            sharingPosts = response.data?.newsStory?.sharingPosts.edges ?? []
            hasNextPage = response.data?.newsStory?.sharingPosts.pageInfo.hasNextPage ?? false
            endCursor = response.data?.newsStory?.sharingPosts.pageInfo.endCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading news story: \(error)")
        }
    }

    private func loadMore() async {
        guard hasNextPage, let endCursor, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.NewsStoryDetailQuery(id: storyId, after: .some(endCursor), first: 20),
                cachePolicy: .networkOnly
            )
            let connection = response.data?.newsStory?.sharingPosts
            let existingIDs = Set(sharingPosts.map(\.node.id))
            sharingPosts.append(contentsOf: (connection?.edges ?? []).filter { !existingIDs.contains($0.node.id) })
            hasNextPage = connection?.pageInfo.hasNextPage ?? false
            self.endCursor = connection?.pageInfo.endCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading more news discussion: \(error)")
        }
    }

    private func openExternalURL(_ value: String) {
        guard let url = URL(string: value) else { return }
        externalURLRouter.open(url)
    }
}

private struct NewsAdminView: View {
    let onDidUpdate: () -> Void

    @State private var status: HackersPub.NewsAdminQuery.Data.NewsScoreStatus?
    @State private var excludedPatterns: [HackersPub.NewsAdminQuery.Data.NewsExcludedPattern] = []
    @State private var penalizedStories: [HackersPub.NewsAdminQuery.Data.NewsPenalizedStory] = []
    @State private var patternInput = ""
    @State private var noteInput = ""
    @State private var isLoading = false
    @State private var isAddingPattern = false
    @State private var isRecomputing = false
    @State private var errorMessage: String?
    @State private var hasLoadedInitial = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && !hasLoadedInitial {
                    ProgressView(NSLocalizedString("timeline.loading", comment: "Loading indicator"))
                } else if let errorMessage, !hasLoadedInitial {
                    LoadFailureView(message: errorMessage) {
                        Task {
                            await fetchAdminState()
                        }
                    }
                } else {
                    adminList
                }
            }
            .navigationTitle(NSLocalizedString("news.admin.title", comment: "News admin title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
            .task {
                guard !hasLoadedInitial else { return }
                await fetchAdminState()
            }
        }
    }

    private var adminList: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if let status {
                    LabeledContent(
                        NSLocalizedString("news.admin.scoredLinks", comment: "Scored links label"),
                        value: String(status.scoredLinkCount)
                    )

                    LabeledContent(NSLocalizedString("news.admin.lastRecomputed", comment: "Last recomputed label")) {
                        if let lastRecomputedAt = status.lastRecomputedAt {
                            Text(DateFormatHelper.relativeTime(from: lastRecomputedAt))
                        } else {
                            Text(NSLocalizedString("news.admin.never", comment: "Never recomputed"))
                        }
                    }
                } else {
                    Text(NSLocalizedString("news.admin.notAvailable", comment: "News admin unavailable"))
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await recomputeScores()
                    }
                } label: {
                    if isRecomputing {
                        ProgressView()
                    } else {
                        Label(NSLocalizedString("news.admin.recompute", comment: "Recompute news scores"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRecomputing)
            } header: {
                Text(NSLocalizedString("news.admin.scores", comment: "News scores section"))
            } footer: {
                Text(NSLocalizedString("news.admin.recompute.description", comment: "Recompute news scores description"))
            }

            Section {
                TextField(NSLocalizedString("news.admin.pattern", comment: "News excluded pattern field"), text: $patternInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                TextField(NSLocalizedString("news.admin.note", comment: "News excluded note field"), text: $noteInput)

                Button {
                    Task {
                        await addPattern()
                    }
                } label: {
                    if isAddingPattern {
                        ProgressView()
                    } else {
                        Label(NSLocalizedString("news.admin.addPattern", comment: "Add news excluded pattern"), systemImage: "plus")
                    }
                }
                .disabled(isAddingPattern || patternInput.nilIfBlank == nil)
            } header: {
                Text(NSLocalizedString("news.admin.excludedPatterns", comment: "Excluded patterns section"))
            } footer: {
                Text(NSLocalizedString("news.admin.excludedPatterns.description", comment: "Excluded patterns description"))
            }

            Section {
                if excludedPatterns.isEmpty {
                    Text(NSLocalizedString("news.admin.noPatterns", comment: "No excluded patterns"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(excludedPatterns, id: \.id) { pattern in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pattern.pattern)
                                .font(.callout.monospaced())
                            if let note = pattern.note?.nilIfBlank {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(DateFormatHelper.relativeTime(from: pattern.created))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    await removePattern(id: pattern.id)
                                }
                            } label: {
                                Label(NSLocalizedString("common.delete", comment: "Delete button"), systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                if penalizedStories.isEmpty {
                    Text(NSLocalizedString("news.admin.noPenalizedStories", comment: "No penalized stories"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(penalizedStories, id: \.id) { story in
                        NavigationLink {
                            NewsStoryDetailView(storyId: story.uuid)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(story.title?.nilIfBlank ?? NewsURLFormatter.host(from: story.url))
                                    .font(.headline)
                                    .lineLimit(2)

                                HStack(spacing: 4) {
                                    Text(NewsURLFormatter.host(from: story.url))
                                    if let penalty = story.penalty?.value {
                                        Text("·")
                                        Text(title(for: penalty))
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button {
                                Task {
                                    await clearPenalty(for: story.uuid)
                                }
                            } label: {
                                Label(NSLocalizedString("news.admin.clearPenalty", comment: "Clear news penalty"), systemImage: "xmark.circle")
                            }
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("news.admin.penalizedStories", comment: "Penalized stories section"))
            } footer: {
                Text(NSLocalizedString("news.admin.penalizedStories.description", comment: "Penalized stories description"))
            }
        }
        .refreshable {
            await fetchAdminState()
        }
    }

    private func fetchAdminState() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoadedInitial = true
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.NewsAdminQuery(),
                cachePolicy: .networkOnly
            )

            guard response.data?.viewer?.moderator == true else {
                errorMessage = NSLocalizedString("news.admin.notAuthorized", comment: "News admin not authorized")
                return
            }

            status = response.data?.newsScoreStatus
            excludedPatterns = response.data?.newsExcludedPatterns ?? []
            penalizedStories = response.data?.newsPenalizedStories ?? []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading news admin state: \(error)")
        }
    }

    private func recomputeScores() async {
        isRecomputing = true
        defer { isRecomputing = false }

        do {
            let response = try await apolloClient.perform(mutation: HackersPub.RecomputeNewsScoresMutation())
            guard response.data?.recomputeNewsScores.asRecomputeNewsScoresPayload != nil else {
                errorMessage = NSLocalizedString("news.admin.recompute.failed", comment: "Recompute news scores failed")
                return
            }

            await fetchAdminState()
            onDidUpdate()
        } catch {
            errorMessage = error.localizedDescription
            print("Error recomputing news scores: \(error)")
        }
    }

    private func addPattern() async {
        guard let pattern = patternInput.nilIfBlank else { return }
        let note = noteInput.nilIfBlank
        isAddingPattern = true
        defer { isAddingPattern = false }

        do {
            let response = try await apolloClient.perform(
                mutation: HackersPub.AddNewsExcludedPatternMutation(
                    pattern: pattern,
                    note: note.map { .some($0) } ?? .none
                )
            )

            guard response.data?.addNewsExcludedPattern.asNewsExcludedPattern != nil else {
                errorMessage = NSLocalizedString("news.admin.addPattern.failed", comment: "Add excluded pattern failed")
                return
            }

            patternInput = ""
            noteInput = ""
            await fetchAdminState()
            onDidUpdate()
        } catch {
            errorMessage = error.localizedDescription
            print("Error adding news excluded pattern: \(error)")
        }
    }

    private func removePattern(id: String) async {
        do {
            let response = try await apolloClient.perform(mutation: HackersPub.RemoveNewsExcludedPatternMutation(id: id))
            guard response.data?.removeNewsExcludedPattern.asRemoveNewsExcludedPatternPayload != nil else {
                errorMessage = NSLocalizedString("news.admin.removePattern.failed", comment: "Remove excluded pattern failed")
                return
            }

            await fetchAdminState()
            onDidUpdate()
        } catch {
            errorMessage = error.localizedDescription
            print("Error removing news excluded pattern: \(error)")
        }
    }

    private func clearPenalty(for storyId: String) async {
        do {
            let response = try await apolloClient.perform(
                mutation: HackersPub.SetNewsScorePenaltyMutation(id: storyId, penalty: .case(.none))
            )
            guard response.data?.setNewsScorePenalty?.asPostLink != nil else {
                errorMessage = NSLocalizedString("news.admin.clearPenalty.failed", comment: "Clear news penalty failed")
                return
            }

            await fetchAdminState()
            onDidUpdate()
        } catch {
            errorMessage = error.localizedDescription
            print("Error clearing news penalty: \(error)")
        }
    }

    private func title(for penalty: HackersPub.NewsPenalty) -> String {
        switch penalty {
        case .bury:
            return NSLocalizedString("news.penalty.bury", comment: "Bury penalty")
        case .demote:
            return NSLocalizedString("news.penalty.demote", comment: "Demote penalty")
        case .none:
            return NSLocalizedString("news.penalty.none", comment: "No penalty")
        }
    }
}

private struct NewsStoryHeaderView: View {
    let story: HackersPub.NewsStoryDetailQuery.Data.NewsStory

    private var title: String {
        story.title?.nilIfBlank ?? host
    }

    private var host: String {
        NewsURLFormatter.host(from: story.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let image = story.image, let url = URL(string: image.url) {
                KFImage(url)
                    .placeholder {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(image.alt ?? "")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let description = story.description?.nilIfBlank {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(
                    String(format: NSLocalizedString("news.opinions.count", comment: "News discussion count"), story.discussionCount),
                    systemImage: "bubble.left.and.bubble.right"
                )

                if let latestActivityAt = story.latestActivityAt {
                    Label(
                        String(format: NSLocalizedString("news.lastActive", comment: "News last active"), DateFormatHelper.relativeTime(from: latestActivityAt)),
                        systemImage: "clock"
                    )
                }

                if let firstSharedAt = story.firstSharedAt {
                    Label(
                        String(format: NSLocalizedString("news.firstShared", comment: "News first shared"), DateFormatHelper.relativeTime(from: firstSharedAt)),
                        systemImage: "calendar"
                    )
                }

                sourceBreakdown
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var sourceBreakdown: some View {
        HStack(spacing: 8) {
            if story.sourceBreakdown.local > 0 {
                Text(String(format: NSLocalizedString("news.source.local", comment: "Local news source count"), story.sourceBreakdown.local))
            }
            if story.sourceBreakdown.remote > 0 {
                Text(String(format: NSLocalizedString("news.source.remote", comment: "Remote news source count"), story.sourceBreakdown.remote))
            }
            if story.sourceBreakdown.bluesky > 0 {
                Text(String(format: NSLocalizedString("news.source.bluesky", comment: "Bluesky news source count"), story.sourceBreakdown.bluesky))
            }
        }
    }
}

private enum NewsURLFormatter {
    static func host(from value: String) -> String {
        guard let host = URL(string: value)?.host else { return value }
        return host.replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
    }
}
