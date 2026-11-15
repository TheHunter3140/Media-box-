import Foundation

/// Énumération des fichiers par un acteur en arrière-plan ; ne retourne que les fichiers nouveaux ou modifiés.
actor FileIndexer {
    struct Candidate: Sendable {
        let path: String
        let url: URL
        let kind: MediaKind
        let size: Int64
        let modified: Date?
    }
    struct ScanResult: Sendable {
        var candidates: [Candidate] = []
        var seen: Set<String> = []
        var complete = false
    }

    func enumerate(base: URL, known: [String: Int64]) -> ScanResult {
        var result = ScanResult()
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let en = FileManager.default.enumerator(at: base, includingPropertiesForKeys: keys,
                                                      options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return result }
        let basePath = base.standardizedFileURL.path
        while let u = en.nextObject() as? URL {
            guard let kind = MediaFormats.kind(forExtension: u.pathExtension) else { continue }
            guard let v = try? u.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            var rel = u.standardizedFileURL.path
            if rel.hasPrefix(basePath) { rel = String(rel.dropFirst(basePath.count)) }
            while rel.hasPrefix("/") { rel.removeFirst() }
            let size = Int64(v.fileSize ?? 0)
            result.seen.insert(rel)
            if known[rel] != size {
                result.candidates.append(Candidate(path: rel, url: u, kind: kind, size: size, modified: v.contentModificationDate))
            }
        }
        result.complete = true
        return result
    }
}
