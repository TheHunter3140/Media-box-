import Foundation

enum MediaKind: String, Codable { case audio, video }
enum RootKind: String, Codable { case appFolder, folder, file }

struct Locator: Codable, Hashable {
    var rootID: String
    var path: String
}

struct LibraryRoot: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var kind: RootKind
    var bookmark: Data?
    var addedAt: Date
    static let appRootID = "app"
    static func appRoot() -> LibraryRoot {
        LibraryRoot(id: appRootID, name: "Dossier MediaBox", kind: .appFolder, bookmark: nil, addedAt: Date())
    }
}

struct MediaItem: Identifiable, Codable, Hashable {
    var id: String
    var locator: Locator
    var kind: MediaKind
    var title: String
    var artist: String?
    var album: String?
    var duration: Double
    var fileSize: Int64
    var modified: Date?
    var addedAt: Date

    var fileName: String { (locator.path as NSString).lastPathComponent }
    var displayArtist: String { (artist ?? "").isEmpty ? "Artiste inconnu" : artist! }
    var hasMetadataGap: Bool { kind == .audio && ((artist ?? "").isEmpty || (album ?? "").isEmpty) }
    static func makeID(_ l: Locator) -> String { l.rootID + "|" + l.path }
}

enum MediaFormats {
    static let audio: Set<String> = ["mp3", "m4a", "aac", "wav", "wave", "aif", "aiff", "caf", "flac", "alac", "mp2"]
    static let video: Set<String> = ["mp4", "m4v", "mov", "3gp"]
    static func kind(forExtension ext: String) -> MediaKind? {
        let e = ext.lowercased()
        if audio.contains(e) { return .audio }
        if video.contains(e) { return .video }
        return nil
    }
}

struct ListeningStats: Codable {
    var totalSeconds: Double = 0
    var tracksPlayed: Int = 0
}

enum Format {
    static func bytes(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }
    static func bytes(_ b: UInt64) -> String { bytes(Int64(clamping: b)) }
    static func mb(_ b: UInt64) -> String { String(format: "%.1f Mo", Double(b) / 1_048_576) }
    static func time(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let t = Int(s)
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}
