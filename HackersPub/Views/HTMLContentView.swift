import SwiftUI
import Kingfisher

actor HTMLCache {
    static let shared = HTMLCache()
    private var cache: [String: AttributedString] = [:]

    func get(_ key: String) -> AttributedString? {
        cache[key]
    }

    func set(_ key: String, value: AttributedString) {
        cache[key] = value
    }
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
    var onTap: (() -> Void)?
    @State private var selectedMedia: MediaItem?
    @State private var webViewHeight: CGFloat = 0
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var carouselHeight: CGFloat {
        guard let firstMedia = media.first,
              let width = firstMedia.width,
              let height = firstMedia.height,
              width > 0 else {
            return 300
        }
        let aspectRatio = CGFloat(height) / CGFloat(width)
        // Assume available width is roughly screen width minus padding
        let estimatedWidth: CGFloat = 350
        return min(estimatedWidth * aspectRatio, 500)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display images in carousel if present
            if !media.isEmpty {
                TabView {
                    ForEach(media) { item in
                        if let thumbnailURL = item.thumbnailUrl.flatMap({ URL(string: $0) }) ?? URL(string: item.url) {
                            KFImage(thumbnailURL)
                                .placeholder {
                                    ZStack {
                                        Color.gray.opacity(0.1)
                                        ProgressView()
                                    }
                                }
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMedia = item
                                }
                        }
                    }
                }
                .tabViewStyle(.page)
                .frame(height: carouselHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Display text content
            HTMLWebView(html: html, height: $webViewHeight, onTap: onTap, navigationCoordinator: navigationCoordinator)
                .frame(height: webViewHeight > 0 ? webViewHeight : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fullScreenCover(item: $selectedMedia) { item in
            FullScreenImageView(mediaItem: item, allMedia: media)
        }
    }
}

struct FullScreenImageView: View {
    let mediaItem: MediaItem
    let allMedia: [MediaItem]
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(mediaItem: MediaItem, allMedia: [MediaItem]) {
        self.mediaItem = mediaItem
        self.allMedia = allMedia
        let index = allMedia.firstIndex(where: { $0.id == mediaItem.id }) ?? 0
        _currentIndex = State(initialValue: index)
    }

    private var currentMedia: MediaItem {
        allMedia[currentIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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

                        if let alt = item.alt, !alt.isEmpty {
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

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
