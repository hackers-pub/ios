import SwiftUI
import UIKit

actor ImageCache {
    static let shared = ImageCache()

    private var memoryCache: [URL: UIImage] = [:]
    private let maxMemoryCacheSize = 50 // Maximum number of images in memory
    private var cacheOrder: [URL] = [] // LRU tracking

    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL? = {
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let imageCache = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: imageCache, withIntermediateDirectories: true)
        return imageCache
    }()

    func get(_ url: URL) -> UIImage? {
        // Check memory cache first
        if let cached = memoryCache[url] {
            updateAccessOrder(url)
            return cached
        }

        // Check disk cache
        if let diskImage = loadFromDisk(url) {
            setInMemory(url, image: diskImage)
            return diskImage
        }

        return nil
    }

    func set(_ url: URL, image: UIImage) {
        setInMemory(url, image: image)
        saveToDisk(url, image: image)
    }

    private func setInMemory(_ url: URL, image: UIImage) {
        memoryCache[url] = image
        updateAccessOrder(url)

        // Evict oldest if over limit
        if cacheOrder.count > maxMemoryCacheSize {
            let oldest = cacheOrder.removeFirst()
            memoryCache.removeValue(forKey: oldest)
        }
    }

    private func updateAccessOrder(_ url: URL) {
        cacheOrder.removeAll { $0 == url }
        cacheOrder.append(url)
    }

    private func cacheFilePath(for url: URL) -> URL? {
        guard let cacheDir = cacheDirectory else { return nil }
        let filename = url.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return cacheDir.appendingPathComponent(filename)
    }

    private func loadFromDisk(_ url: URL) -> UIImage? {
        guard let filePath = cacheFilePath(for: url),
              let data = try? Data(contentsOf: filePath),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private func saveToDisk(_ url: URL, image: UIImage) {
        guard let filePath = cacheFilePath(for: url),
              let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        try? data.write(to: filePath)
    }

    func clear() {
        memoryCache.removeAll()
        cacheOrder.removeAll()

        if let cacheDir = cacheDirectory {
            try? fileManager.removeItem(at: cacheDir)
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else { return }

        // Check cache first
        if let cached = await ImageCache.shared.get(url) {
            image = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                await ImageCache.shared.set(url, image: downloadedImage)
                image = downloadedImage
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
}
