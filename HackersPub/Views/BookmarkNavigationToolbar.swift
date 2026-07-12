import SwiftUI

struct BookmarkNavigationToolbar: ToolbarContent {
    @Binding var showingComposeView: Bool
    @Binding var selectedFilter: BookmarkFilter
    @Binding var showingSettings: Bool
    @Binding var showingArticleEditor: Bool
    @Binding var showingArticleDrafts: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            ViewerProfileButton()

            Button {
                showingSettings = true
            } label: {
                Label(NSLocalizedString("common.settings", comment: "Settings button"), systemImage: "gear")
            }
        }

        ToolbarItem(placement: .principal) {
            Picker(
                NSLocalizedString("bookmarks.filter", comment: "Bookmarks filter picker"),
                selection: $selectedFilter
            ) {
                ForEach(BookmarkFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showingComposeView = true
                } label: {
                    Label(
                        NSLocalizedString("common.newPost", comment: "New note button"),
                        systemImage: "square.and.pencil"
                    )
                }
                Button {
                    showingArticleEditor = true
                } label: {
                    Label(NSLocalizedString("article.new", comment: "New article"), systemImage: "doc.badge.plus")
                }
                Button {
                    showingArticleDrafts = true
                } label: {
                    Label(NSLocalizedString("article.drafts", comment: "Article drafts"), systemImage: "tray.full")
                }
            } label: {
                Label(NSLocalizedString("common.compose", comment: "Compose menu"), systemImage: "plus")
            }
        }
    }
}
