import Foundation

/// Résolution des fichiers : dossier de l'app, dossiers externes et fichiers isolés via signets de sécurité.
@MainActor
final class FileAccessManager {
    static let shared = FileAccessManager()

    private var resolved: [String: URL] = [:]
    private var scopedFolders: Set<String> = []
    private var scopedFiles: [String] = []          // LRU des fichiers isolés ouverts
    private let maxOpenFiles = 8
    var onBookmarkRefreshed: ((String, Data) -> Void)?

    static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func rootURL(for root: LibraryRoot) -> URL? {
        if root.kind == .appFolder { return FileManagerService.mediaRoot }
        if let u = resolved[root.id] { return u }
        guard let data = root.bookmark else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        resolved[root.id] = url
        if root.kind == .folder { scopedFolders.insert(root.id) } else { touchFile(root.id) }
        if stale, let fresh = try? FileAccessManager.makeBookmark(for: url) { onBookmarkRefreshed?(root.id, fresh) }
        return url
    }

    func url(for locator: Locator, root: LibraryRoot?) -> URL? {
        guard let root = root, let base = rootURL(for: root) else { return nil }
        switch root.kind {
        case .file: touchFile(root.id); return base
        case .appFolder, .folder: return base.appendingPathComponent(locator.path)
        }
    }

    private func touchFile(_ id: String) {
        scopedFiles.removeAll { $0 == id }
        scopedFiles.append(id)
        while scopedFiles.count > maxOpenFiles {
            let old = scopedFiles.removeFirst()
            if let u = resolved[old] { u.stopAccessingSecurityScopedResource() }
            resolved[old] = nil
        }
    }

    func forget(rootID: String) {
        if let u = resolved[rootID] { u.stopAccessingSecurityScopedResource() }
        resolved[rootID] = nil
        scopedFolders.remove(rootID)
        scopedFiles.removeAll { $0 == rootID }
    }

    func releaseAll() {
        for (_, u) in resolved { u.stopAccessingSecurityScopedResource() }
        resolved.removeAll(); scopedFolders.removeAll(); scopedFiles.removeAll()
    }
}
