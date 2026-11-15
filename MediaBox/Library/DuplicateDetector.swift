import Foundation
import CryptoKit

/// Détection en 3 passes, à la demande (jamais en continu) :
/// 1) même taille  2) durées proches  3) empreinte partielle (64 Ko début + 64 Ko fin).
enum DuplicateDetector {
    static func candidateGroups(_ items: [MediaItem]) -> [[MediaItem]] {
        var bySize: [Int64: [MediaItem]] = [:]
        for i in items where i.fileSize > 0 { bySize[i.fileSize, default: []].append(i) }
        var groups: [[MediaItem]] = []
        for (_, g) in bySize where g.count > 1 {
            let sorted = g.sorted { $0.duration < $1.duration }
            var current: [MediaItem] = [sorted[0]]
            for it in sorted.dropFirst() {
                if abs(it.duration - (current.last?.duration ?? 0)) <= 0.5 { current.append(it) }
                else { if current.count > 1 { groups.append(current) }; current = [it] }
            }
            if current.count > 1 { groups.append(current) }
        }
        return groups
    }

    static func partialHash(url: URL, size: Int64) -> String? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        let chunk = 65_536
        var hasher = SHA256()
        if let head = try? fh.read(upToCount: chunk) { hasher.update(data: head) }
        if size > Int64(chunk * 2) {
            try? fh.seek(toOffset: UInt64(size) - UInt64(chunk))
            if let tail = try? fh.read(upToCount: chunk) { hasher.update(data: tail) }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func findDuplicates(items: [MediaItem], urls: [String: URL]) async -> [[MediaItem]] {
        await Task.detached(priority: .utility) {
            var out: [[MediaItem]] = []
            for group in candidateGroups(items) {
                var byHash: [String: [MediaItem]] = [:]
                for it in group {
                    guard let u = urls[it.id], let h = partialHash(url: u, size: it.fileSize) else { continue }
                    byHash[h, default: []].append(it)
                }
                out.append(contentsOf: byHash.values.filter { $0.count > 1 })
            }
            return out
        }.value
    }
}
