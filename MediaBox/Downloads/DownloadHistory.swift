import Foundation

struct DownloadHistoryEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var url: String
    var filename: String
    var destination: String
    var bytes: Int64
    var date: Date
    var success: Bool
    var path: String?        // chemin relatif à Documents/MediaBox
}

@MainActor
final class DownloadHistory: ObservableObject {
    @Published private(set) var entries: [DownloadHistoryEntry] = []
    private let fileURL: URL
    private let cap = 500

    init(fileURL: URL = FileManagerService.supportDir.appendingPathComponent("download-history.json")) {
        self.fileURL = fileURL
        if let d = try? Data(contentsOf: fileURL), let e = try? JSONDecoder().decode([DownloadHistoryEntry].self, from: d) { entries = e }
    }

    func add(_ e: DownloadHistoryEntry) {
        entries.insert(e, at: 0)
        if entries.count > cap { entries.removeLast(entries.count - cap) }
        save()
    }
    func remove(ids: Set<UUID>) { entries.removeAll { ids.contains($0.id) }; save() }
    func clear() { entries = []; save() }
    func contains(url: String) -> DownloadHistoryEntry? {
        entries.first { $0.success && $0.url == url && fileExists($0) }
    }
    func fileExists(_ e: DownloadHistoryEntry) -> Bool {
        guard let p = e.path else { return false }
        return FileManager.default.fileExists(atPath: FileManagerService.mediaRoot.appendingPathComponent(p).path)
    }
    private func save() {
        if let d = try? JSONEncoder().encode(entries) { try? d.write(to: fileURL, options: .atomic) }
    }
}
