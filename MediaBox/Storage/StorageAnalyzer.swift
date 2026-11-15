import Foundation

struct StorageReport {
    var freeSpace: Int64 = 0
    var musicBytes: Int64 = 0
    var videosBytes: Int64 = 0
    var downloadsBytes: Int64 = 0
    var cacheBytes: Int64 = 0
    var supportBytes: Int64 = 0
}

@MainActor
final class StorageAnalyzer: ObservableObject {
    @Published private(set) var report = StorageReport()
    @Published private(set) var largeFiles: [MediaItem] = []
    @Published private(set) var oldDownloads: [DownloadHistoryEntry] = []
    @Published private(set) var duplicateGroups: [[MediaItem]] = []
    @Published private(set) var busy = false

    private let library: MediaLibrary
    private let history: DownloadHistory

    init(library: MediaLibrary, history: DownloadHistory) {
        self.library = library
        self.history = history
    }

    func analyze() async {
        busy = true
        defer { busy = false }
        let r = await Task.detached(priority: .utility) { () -> StorageReport in
            let fs = FileManagerService.shared
            var rep = StorageReport()
            rep.freeSpace = fs.freeSpace() ?? 0
            rep.musicBytes = fs.directorySize(FileManagerService.musicDir)
            rep.videosBytes = fs.directorySize(FileManagerService.videosDir)
            rep.downloadsBytes = fs.directorySize(FileManagerService.downloadsDir)
            rep.cacheBytes = fs.directorySize(FileManagerService.cachesRoot)
            rep.supportBytes = fs.directorySize(FileManagerService.supportDir)
            return rep
        }.value
        report = r
        largeFiles = Array(library.items.sorted { $0.fileSize > $1.fileSize }.prefix(25))
        refreshOldDownloads(days: 30)
    }

    func refreshOldDownloads(days: Int) {
        let limit = Date().addingTimeInterval(-Double(days) * 86400)
        oldDownloads = history.entries.filter { $0.success && $0.date < limit }
    }

    func findDuplicates() async {
        busy = true
        defer { busy = false }
        let items = library.items
        var urls: [String: URL] = [:]
        for i in items { if let u = library.url(for: i) { urls[i.id] = u } }
        duplicateGroups = await DuplicateDetector.findDuplicates(items: items, urls: urls)
    }
}
