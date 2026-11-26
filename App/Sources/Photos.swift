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
    /// What shows behind the picture (and while it loads).
    var backdrop: Color = Theme.line
    @State private var image: CGImage?

    var body: some View {
        Rectangle()
            .fill(backdrop)
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


// MARK: - Seeing a picture large (6.3)

/// Which picture the viewer opens on.
struct ViewerStart: Identifiable { let id: Int }

extension View {
    /// Opens the pictures large when `start` gets a number: full screen on iPhone and iPad, a large window-sheet on the Mac.
    /// `captions` (6.7): one line of words under each picture (the photo story); empty = none.
    func photoViewer(_ urls: [URL], start: Binding<Int?>, captions: [String] = []) -> some View {
        let item = Binding<ViewerStart?>(get: { start.wrappedValue.map(ViewerStart.init) }, set: { start.wrappedValue = $0?.id })
        #if os(iOS)
        return self.fullScreenCover(item: item) { s in PhotoViewer(urls: urls, start: s.id, captions: captions) }
        #else
        return self.sheet(item: item) { s in PhotoViewer(urls: urls, start: s.id, captions: captions).frame(minWidth: 720, idealWidth: 980, minHeight: 560, idealHeight: 760) }   // as large as the window allows
        #endif
    }
}

/// The pictures of one jar, recipe or bake, one at a time, as large as they fit, on a dark page.
/// iPhone/iPad: swipe left and right. Mac: Previous / Next (and the arrow keys); Escape closes.
struct PhotoViewer: View {
    let urls: [URL]
    /// Words under each picture (the jar's photo story, 6.7); empty = none.
    var captions: [String] = []
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(urls: [URL], start: Int, captions: [String] = []) {
        self.urls = urls
        self.captions = captions
        _index = State(initialValue: min(max(0, start), max(0, urls.count - 1)))
    }

    private var caption: String { captions.indices.contains(index) ? captions[index] : "" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            #if os(iOS)
            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { i, u in
                    PhotoImage(url: u, contentMode: .fit, backdrop: .black).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            #else
            if urls.indices.contains(index) { PhotoImage(url: urls[index], contentMode: .fit, backdrop: .black).padding(.top, 44).padding(.bottom, captions.isEmpty ? 44 : 84) }
            #endif
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if !caption.isEmpty { captionLine }
                #if os(macOS)
                if urls.count > 1 { macButtons }
                #endif
            }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("photo-viewer")
    }

    private var topBar: some View {
        HStack {
            Text(urls.count > 1 ? "\(index + 1) of \(urls.count)" : "")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85)).monospacedDigit()
                .accessibilityIdentifier("photo-viewer-count")
            Spacer()
            Button("Done") { dismiss() }
                .font(.body.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Color.white.opacity(0.18), in: Capsule())
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("photo-viewer-done")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    /// The words under a picture of the photo story: its day, time and the line's words.
    private var captionLine: some View {
        Text(caption)
            .font(.subheadline).foregroundStyle(.white)
            .multilineTextAlignment(.center).lineLimit(3)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 16)
            #if os(iOS)
            .padding(.bottom, 8)
            #endif
            .accessibilityIdentifier("photo-viewer-caption")
    }

    #if os(macOS)
    private var macButtons: some View {
        HStack(spacing: 12) {
            Button("Previous") { index = max(0, index - 1) }
                .keyboardShortcut(.leftArrow, modifiers: []).disabled(index == 0)
                .accessibilityIdentifier("photo-viewer-previous")
            Button("Next") { index = min(urls.count - 1, index + 1) }
                .keyboardShortcut(.rightArrow, modifiers: []).disabled(index >= urls.count - 1)
                .accessibilityIdentifier("photo-viewer-next")
        }
        .controlSize(.large)
        .padding(.bottom, 10)
    }
    #endif
}
