import Foundation

/// Accès au système de fichiers de l'app. Thread-safe (n'utilise que FileManager.default).
final class FileManagerService {
    static let shared = FileManagerService()

    static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var mediaRoot: URL { documents.appendingPathComponent("MediaBox", isDirectory: true) }
    static var musicDir: URL { mediaRoot.appendingPathComponent("Musique", isDirectory: true) }
    static var videosDir: URL { mediaRoot.appendingPathComponent("Vidéos", isDirectory: true) }
    static var downloadsDir: URL { mediaRoot.appendingPathComponent("Téléchargements", isDirectory: true) }
    static var supportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MediaBox", isDirectory: true)
    }
    static var cachesRoot: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MediaBox", isDirectory: true)
    }

    /// Crée les dossiers visibles dans l'app Fichiers (« Sur mon iPhone > MediaBox »).
    static func bootstrap() {
        let fm = FileManager.default
        for dir in [mediaRoot, musicDir, videosDir, downloadsDir, supportDir, cachesRoot] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func destinationDirectory(for key: String) -> URL {
        switch key {
        case "music": return musicDir
        case "videos": return videosDir
        default: return downloadsDir
        }
    }

    static func sanitize(_ name: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        var s = name.components(separatedBy: bad).joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty || s == "." || s == ".." { s = "fichier" }
        if s.count > 120 {
            let ext = (s as NSString).pathExtension
            let base = String((s as NSString).deletingPathExtension.prefix(100))
            s = ext.isEmpty ? base : base + "." + ext
        }
        return s
    }

    static func uniqueURL(in dir: URL, name: String) -> URL {
        let fm = FileManager.default
        var url = dir.appendingPathComponent(name)
        guard fm.fileExists(atPath: url.path) else { return url }
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            url = dir.appendingPathComponent(candidate)
            if !fm.fileExists(atPath: url.path) { return url }
            n += 1
        }
    }

    func directorySize(_ url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        while let u = en.nextObject() as? URL {
            if let v = try? u.resourceValues(forKeys: Set(keys)), v.isRegularFile == true { total += Int64(v.fileSize ?? 0) }
        }
        return total
    }

    func freeSpace() -> Int64? {
        let v = try? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return v?.volumeAvailableCapacityForImportantUsage
    }

    /// Copie dans la bibliothèque gérée (uniquement sur demande). Retourne le chemin relatif à `mediaRoot`.
    func importCopy(from url: URL, kind: MediaKind) throws -> String {
        let dir = kind == .audio ? FileManagerService.musicDir : FileManagerService.videosDir
        let dest = FileManagerService.uniqueURL(in: dir, name: FileManagerService.sanitize(url.lastPathComponent))
        try FileManager.default.copyItem(at: url, to: dest)
        return dest.path.replacingOccurrences(of: FileManagerService.mediaRoot.path + "/", with: "")
    }

    func delete(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
}
