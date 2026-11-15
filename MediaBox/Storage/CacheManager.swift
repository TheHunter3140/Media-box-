import Foundation
import UIKit
import CryptoKit

/// Cache d'images borné (mémoire : 60 images / 5 Mo ; disque : 20 Mo par défaut, purge LRU).
final class CacheManager {
    static let shared = CacheManager()

    let memory = NSCache<NSString, UIImage>()
    let directory: URL
    var diskLimitBytes: Int64 = 20 * 1024 * 1024
    private let io = DispatchQueue(label: "mediabox.cache.io", qos: .utility)
    private let lock = NSLock()
    private var missing = Set<String>()

    init(directory: URL = FileManagerService.cachesRoot.appendingPathComponent("thumbs", isDirectory: true)) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 60
        memory.totalCostLimit = 5 * 1024 * 1024
    }

    private func file(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(String(digest.prefix(40)) + ".jpg")
    }

    func image(forKey key: String) -> UIImage? {
        if let m = memory.object(forKey: key as NSString) { return m }
        let f = file(for: key)
        guard let data = try? Data(contentsOf: f), let img = UIImage(data: data) else { return nil }
        memory.setObject(img, forKey: key as NSString, cost: data.count)
        return img
    }

    func store(_ image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        memory.setObject(image, forKey: key as NSString, cost: data.count)
        let f = file(for: key)
        io.async { [weak self] in
            try? data.write(to: f, options: .atomic)
            self?.trimDisk(to: self?.diskLimitBytes ?? 0)
        }
    }

    func isMissing(_ key: String) -> Bool { lock.lock(); defer { lock.unlock() }; return missing.contains(key) }
    func markMissing(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        if missing.count > 3000 { missing.removeAll() }
        missing.insert(key)
    }

    func diskSize() -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return 0 }
        return files.reduce(Int64(0)) { $0 + Int64((try? $1.resourceValues(forKeys: Set(keys)).fileSize) ?? 0) }
    }

    /// Supprime les fichiers les plus anciens jusqu'à repasser sous `bytes`.
    func trimDisk(to bytes: Int64) {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return }
        var entries: [(URL, Int64, Date)] = files.map {
            let v = try? $0.resourceValues(forKeys: Set(keys))
            return ($0, Int64(v?.fileSize ?? 0), v?.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(Int64(0)) { $0 + $1.1 }
        guard total > bytes else { return }
        entries.sort { $0.2 < $1.2 }
        for e in entries where total > bytes {
            try? FileManager.default.removeItem(at: e.0)
            total -= e.1
        }
    }

    func purgeMemory() { memory.removeAllObjects() }

    func purgeAll() {
        purgeMemory()
        lock.lock(); missing.removeAll(); lock.unlock()
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for f in files { try? FileManager.default.removeItem(at: f) }
        }
    }
}
