import Kingfisher
import SafariServices
import SwiftUI
import UIKit

enum HTMLContentRenderMode {
    case richWebView
    case lightweightText
}

struct MediaItem: Identifiable {
    let id = UUID()
    let url: String
    let thumbnailUrl: String?
    let alt: String?
    let width: Int?
    let height: Int?
}

struct HTMLContentView: View {
    let html: String
    let media: [MediaItem]
    var renderMode: HTMLContentRenderMode = .richWebView
    var onTap: (() -> Void)?
    var suppressLongPressInteractions: Bool = false
    var sneakPeekPostId: String?
    var sneakPeekActorHandle: String?
    var sneakPeekShareURL: URL?
    @State private var selectedMedia: MediaItem?
    @State private var webViewHeight: CGFloat = 0
    @State private var lightweightTextHeight: CGFloat = 0
    @State private var isLoading: Bool = true
    @State private var isVisible: Bool = false
    @State private var mediaActionMessage: String?
    @State private var isSavingImage = false
    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(ExternalURLRouter.self) private var externalURLRouter

    private var carouselHeight: CGFloat {
        guard let firstMedia = media.first,
              let width = firstMedia.width,
              let height = firstMedia.height,
              width > 0
        else {
            return 300
        }
        let aspectRatio = CGFloat(height) / CGFloat(width)
        // Assume available width is roughly screen width minus padding
        let estimatedWidth: CGFloat = 350
        return min(estimatedWidth * aspectRatio, 500)
    }

    private func previewSize(for item: MediaItem) -> CGSize {
        guard let width = item.width,
              let height = item.height,
              width > 0,
              height > 0
        else {
            return CGSize(width: 320, height: 420)
        }

        let maxWidth = min(UIScreen.main.bounds.width - 48, 380)
        let maxHeight = min(UIScreen.main.bounds.height - 220, 560)
        let scale = min(maxWidth / CGFloat(width), maxHeight / CGFloat(height))

        return CGSize(
            width: CGFloat(width) * scale,
            height: CGFloat(height) * scale
        )
    }

    /// Estimate minimum height based on HTML content length
    private var estimatedMinHeight: CGFloat {
        let characterCount = html.count
        // Rough estimation: ~40 characters per line, ~20pt line height
        let estimatedLines = max(2, CGFloat(characterCount) / 40)
        return min(estimatedLines * 20, 200) // Cap at 200pt for initial estimate
    }

    private var containsComplexLayoutHTML: Bool {
        let normalized = html.lowercased()
        return normalized.contains("<pre")
            || normalized.contains("<table")
    }

    private var usesRichWebView: Bool {
        renderMode == .richWebView || containsComplexLayoutHTML
    }

    private var usesInteractiveLightweightText: Bool {
        onTap != nil || sneakPeekPostId != nil
    }

    private var mediaDownsamplingSize: CGSize {
        CGSize(width: 350 * UIScreen.main.scale, height: carouselHeight * UIScreen.main.scale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if usesRichWebView {
                // Display text content with smooth transition
                ZStack(alignment: .topLeading) {
                    // Placeholder skeleton while loading
                    if isLoading, webViewHeight == 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 16)
                                .frame(maxWidth: .infinity)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 16)
                                .frame(maxWidth: .infinity)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 16)
                                .frame(maxWidth: 200)
                        }
                        .frame(minHeight: estimatedMinHeight)
                        .redacted(reason: .placeholder)
                        .shimmering()
                    }

                    // Only mount the web view once the cell has scrolled into view
                    if isVisible {
                        HTMLWebView(
                            html: html,
                            height: $webViewHeight,
                            onTap: onTap,
                            authManager: authManager,
                            navigationCoordinator: navigationCoordinator,
                            externalURLRouter: externalURLRouter,
                            suppressLongPressInteractions: suppressLongPressInteractions,
                            sneakPeekPostId: sneakPeekPostId,
                            sneakPeekActorHandle: sneakPeekActorHandle,
                            sneakPeekShareURL: sneakPeekShareURL,
                            onLinkPressStateChange: nil
                        )
                        .id(sneakPeekPostId ?? html)
                        .frame(height: webViewHeight > 0 ? webViewHeight : estimatedMinHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(webViewHeight > 0 ? 1 : 0)
                        .onChange(of: webViewHeight) { _, newValue in
                            if newValue > 0, isLoading {
                                isLoading = false
                            }
                        }
                    }
                }
                .id(sneakPeekPostId ?? html)
                // Gate heavy web-view creation on actual visibility
                .onAppear {
                    isVisible = true
                }
            } else if usesInteractiveLightweightText {
                InteractiveHTMLTextView(
                    html: html,
                    height: $lightweightTextHeight,
                    font: .body,
                    color: .primary,
                    onTap: onTap,
                    authManager: authManager,
                    navigationCoordinator: navigationCoordinator,
                    externalURLRouter: externalURLRouter,
                    sneakPeekPostId: sneakPeekPostId,
                    sneakPeekShareURL: sneakPeekShareURL
                )
                    .frame(height: lightweightTextHeight > 0 ? lightweightTextHeight : estimatedMinHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    .onChange(of: html) { _, _ in
                        lightweightTextHeight = 0
                    }
            } else {
                HTMLTextView(html: html)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
            }

            // Display images in carousel if present
            if !media.isEmpty {
                TabView {
                    ForEach(media) { item in
                        let resolved = item.thumbnailUrl.flatMap { URL(string: $0) } ?? URL(string: item.url)
                        if let thumbnailURL = resolved {
                            KFImage(thumbnailURL)
                                .placeholder {
                                    ZStack {
                                        Color.gray.opacity(0.1)
                                        ProgressView()
                                    }
                                }
                                .downsampling(size: mediaDownsamplingSize)
                                .cancelOnDisappear(true)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMedia = item
                                }
                                .uiContextMenu(
                                    makeConfiguration: {
                                        makeMediaContextMenuConfiguration(for: item)
                                    },
                                    onCommit: {
                                        selectedMedia = item
                                    }
                                )
                        }
                    }
                }
                .tabViewStyle(.page)
                .frame(height: carouselHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .fullScreenCover(item: $selectedMedia) { item in
            FullScreenImageView(
                mediaItem: item,
                allMedia: media,
                onClose: {
                    selectedMedia = nil
                }
            )
        }
        .alert(
            NSLocalizedString("image.action.alertTitle", comment: "Image action result title"),
            isPresented: Binding(
                get: { mediaActionMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        mediaActionMessage = nil
                    }
                }
            )
        ) {
            Button(NSLocalizedString("compose.error.ok", comment: "OK button"), role: .cancel) {
                mediaActionMessage = nil
            }
        } message: {
            Text(mediaActionMessage ?? "")
        }
    }

    private func openLink(_ url: URL) {
        if url.host == "hackers.pub", url.path.hasPrefix("/@") {
            let handle = String(url.path.dropFirst(2))
            navigationCoordinator.navigateToProfile(handle: handle)
        } else {
            externalURLRouter.open(url)
        }
    }

    private func makePostContextMenuConfiguration() -> UIContextMenuConfiguration? {
        guard let sneakPeekPostId else { return nil }

        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: {
                let preview = PostDetailView(postId: sneakPeekPostId)
                    .frame(width: 360, height: 560)
                    .ignoresSafeArea()
                    .environment(authManager)
                    .environment(navigationCoordinator)
                    .environment(externalURLRouter)
                    .environmentObject(FontSettingsManager.shared)
                let controller = UIHostingController(rootView: preview)
                controller.view.backgroundColor = .systemBackground
                controller.view.insetsLayoutMarginsFromSafeArea = false
                controller.view.directionalLayoutMargins = .zero
                return controller
            },
            actionProvider: { _ in
                makePostContextMenu()
            }
        )
    }

    private func makePostContextMenu() -> UIMenu {
        var children: [UIMenuElement] = []

        if let sneakPeekShareURL {
            let shareAction = UIAction(
                title: NSLocalizedString("sneakpeek.action.sharePost", comment: "Share post"),
                image: UIImage(systemName: "square.and.arrow.up")
            ) { _ in
                ShareSheetPresenter.present(items: [sneakPeekShareURL])
            }
            children.append(shareAction)
        }

        return UIMenu(children: children)
    }

    private func makeLinkContextMenuConfiguration(url: URL) -> UIContextMenuConfiguration {
        UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: {
                SFSafariViewController(url: url)
            },
            actionProvider: { _ in
                let openAction = UIAction(
                    title: NSLocalizedString("sneakpeek.action.openLink", comment: "Open link"),
                    image: UIImage(systemName: "safari")
                ) { _ in
                    openLink(url)
                }

                let shareAction = UIAction(
                    title: NSLocalizedString("sneakpeek.action.shareLink", comment: "Share link"),
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { _ in
                    ShareSheetPresenter.present(items: [url])
                }

                return UIMenu(children: [openAction, shareAction])
            }
        )
    }

    private func saveImage(_ item: MediaItem) {
        guard !isSavingImage else { return }
        isSavingImage = true

        Task {
            defer { isSavingImage = false }
            do {
                try await ImageDownloadService.downloadToPhotoLibrary(from: item.url)
                mediaActionMessage = NSLocalizedString("image.download.success", comment: "Image download succeeded")
            } catch {
                mediaActionMessage = error.localizedDescription
            }
        }
    }

    private func makeMediaContextMenuConfiguration(for item: MediaItem) -> UIContextMenuConfiguration {
        UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: {
                let previewSize = previewSize(for: item)
                let preview = ImageSneakPeekPreview(item: item)
                    .frame(width: previewSize.width, height: previewSize.height)
                let controller = UIHostingController(rootView: preview)
                controller.view.backgroundColor = .systemBackground
                controller.preferredContentSize = previewSize
                return controller
            },
            actionProvider: { _ in
                makeMediaContextMenu(for: item)
            }
        )
    }

    private func makeMediaContextMenu(for item: MediaItem) -> UIMenu {
        let downloadTitle = isSavingImage
            ? NSLocalizedString("image.action.downloading", comment: "Downloading image")
            : NSLocalizedString("image.action.download", comment: "Download image")
        let downloadAttributes: UIMenuElement.Attributes = isSavingImage ? [.disabled] : []

        var elements: [UIMenuElement] = [
            UIAction(
                title: downloadTitle,
                image: UIImage(systemName: "arrow.down.circle"),
                attributes: downloadAttributes
            ) { _ in
                saveImage(item)
            }
        ]

        if let mediaURL = URL(string: item.url) {
            elements.append(
                UIAction(
                    title: NSLocalizedString("image.action.share", comment: "Share image"),
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { _ in
                    ShareSheetPresenter.present(items: [mediaURL])
                }
            )
        }

        return UIMenu(children: elements)
    }
}

private struct ImageSneakPeekPreview: View {
    let item: MediaItem

    var body: some View {
        ZStack {
            Color.black

            if let url = URL(string: item.url) {
                KFImage(url)
                    .placeholder {
                        ProgressView()
                    }
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Shimmer effect for skeleton loading
extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase)
                    .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.0)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 400
                }
            }
    }
}

struct FullScreenImageView: View {
    let mediaItem: MediaItem
    let allMedia: [MediaItem]
    let showsToolbar: Bool
    let showsAltText: Bool
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var actionMessage: String?
    @State private var isSavingImage = false

    init(
        mediaItem: MediaItem,
        allMedia: [MediaItem],
        showsToolbar: Bool = true,
        showsAltText: Bool = true,
        onClose: (() -> Void)? = nil
    ) {
        self.mediaItem = mediaItem
        self.allMedia = allMedia
        self.showsToolbar = showsToolbar
        self.showsAltText = showsAltText
        self.onClose = onClose
        let index = allMedia.firstIndex(where: { $0.id == mediaItem.id }) ?? 0
        _currentIndex = State(initialValue: index)
    }

    private var currentMedia: MediaItem {
        allMedia[currentIndex]
    }

    @ViewBuilder
    private var imagePager: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(allMedia.enumerated()), id: \.element.id) { index, item in
                VStack {
                    if let url = URL(string: item.url) {
                        KFImage(url)
                            .placeholder {
                                ProgressView()
                            }
                            .resizable()
                            .scaledToFit()
                    }

                    if showsAltText, let alt = item.alt, !alt.isEmpty {
                        Text(alt)
                            .font(.body)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding()
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    var body: some View {
        Group {
            if showsToolbar {
                NavigationStack {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        imagePager
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                onClose?()
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button {
                                saveCurrentImage()
                            } label: {
                                if isSavingImage {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.down")
                                }
                            }
                            .disabled(isSavingImage)

                            if let currentMediaURL = URL(string: currentMedia.url) {
                                ShareLink(item: currentMediaURL) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbarBackground(Color.black, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                }
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    imagePager
                }
            }
        }
        .alert(
            NSLocalizedString("image.action.alertTitle", comment: "Image action result title"),
            isPresented: Binding(
                get: { actionMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        actionMessage = nil
                    }
                }
            )
        ) {
            Button(NSLocalizedString("compose.error.ok", comment: "OK button"), role: .cancel) {
                actionMessage = nil
            }
        } message: {
            Text(actionMessage ?? "")
        }
    }

    private func saveCurrentImage() {
        guard !isSavingImage else { return }
        isSavingImage = true

        Task {
            defer { isSavingImage = false }
            do {
                try await ImageDownloadService.downloadToPhotoLibrary(from: currentMedia.url)
                actionMessage = NSLocalizedString("image.download.success", comment: "Image download succeeded")
            } catch {
                actionMessage = error.localizedDescription
            }
        }
    }
}
