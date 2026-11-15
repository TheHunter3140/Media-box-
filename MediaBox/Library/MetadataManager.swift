import Foundation
import AVFoundation
import UIKit

struct MediaMetadata {
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double
}

enum MetadataManager {
    static func read(url: URL, kind: MediaKind) async -> MediaMetadata {
        let asset = AVURLAsset(url: url)
        var meta = MediaMetadata(title: nil, artist: nil, album: nil, duration: 0)
        if let d = try? await asset.load(.duration) {
            let s = d.seconds
            if s.isFinite && s > 0 { meta.duration = s }
        }
        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                guard let id = item.identifier else { continue }
                if id == .commonIdentifierTitle { meta.title = try? await item.load(.stringValue) }
                else if id == .commonIdentifierArtist { meta.artist = try? await item.load(.stringValue) }
                else if id == .commonIdentifierAlbumName { meta.album = try? await item.load(.stringValue) }
            }
        }
        return meta
    }

    static func artworkData(url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return nil }
        for item in items where item.identifier == .commonIdentifierArtwork {
            if let data = try? await item.load(.dataValue) { return data }
        }
        return nil
    }

    static func downsample(_ data: Data, maxPixel: Int) -> UIImage? {
        let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts as CFDictionary) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

actor Gate {
    private var running = 0
    private let limit: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(limit: Int) { self.limit = limit }
    func enter() async {
        if running < limit { running += 1 } else { await withCheckedContinuation { waiters.append($0) } }
    }
    func leave() {
        if waiters.isEmpty { running -= 1 } else { waiters.removeFirst().resume() }
    }
}

/// Miniatures générées à la demande (2 en parallèle max), cache borné.
enum ArtworkLoader {
    private static let gate = Gate(limit: 2)

    static func load(item: MediaItem, url: URL?, maxPixel: Int) async -> UIImage? {
        let key = "\(item.id)#\(maxPixel)"
        let cache = CacheManager.shared
        if let img = cache.image(forKey: key) { return img }
        if cache.isMissing(key) { return nil }
        guard let url = url else { return nil }
        await gate.enter()
        var result: UIImage?
        if item.kind == .audio {
            if let data = await MetadataManager.artworkData(url: url) { result = MetadataManager.downsample(data, maxPixel: maxPixel) }
        } else {
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: maxPixel, height: maxPixel)
            if let r = try? await gen.image(at: CMTime(seconds: 1, preferredTimescale: 600)) { result = UIImage(cgImage: r.image) }
        }
        await gate.leave()
        if let r = result { cache.store(r, key: key) } else { cache.markMissing(key) }
        return result
    }
}
