import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Picture files: shrunk once when they come in, read back off the main thread when shown.
enum PhotoFile {
    static let maxPixels = 1600
    static let quality: CGFloat = 0.8

    /// The picture at most 1600 pixels on its longer side, turned the right way up, as JPEG (0.8).
    /// nil = the data is not a picture.
    static func shrink(_ data: Data, maxPixels: Int = PhotoFile.maxPixels, quality: CGFloat = PhotoFile.quality) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}

/// A small in-memory cache of decoded pictures. An actor, so decoding never runs on the main thread.
actor PhotoCache {
    static let shared = PhotoCache()
    private let cache = NSCache<NSURL, CGImage>()
    private init() { cache.countLimit = 150 }

    func image(for url: URL?) -> CGImage? {
        guard let url else { return nil }
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: PhotoFile.maxPixels,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        cache.setObject(cg, forKey: url as NSURL)
        return cg
    }
    func forget(_ url: URL) { cache.removeObject(forKey: url as NSURL) }
}

/// A picture from the Photos folder, or a soft square while there is none. A picture still coming down from iCloud
/// is looked for again every two seconds (up to ten times).
struct PhotoImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @State private var image: CGImage?

    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: contentMode)
                }
            }
            .clipped()
            .task(id: url) {
                image = nil
                for _ in 0..<10 {
                    image = await PhotoCache.shared.image(for: url)
                    if image != nil || url == nil { break }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
            .accessibilityHidden(true)
    }
}
