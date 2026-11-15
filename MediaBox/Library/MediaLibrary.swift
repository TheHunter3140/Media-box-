import Foundation
import Combine

private struct LibrarySnapshot: Codable {
    var roots: [LibraryRoot] = []
    var items: [MediaItem] = []
    var positions: [String: Double] = [:]
    var playCounts: [String: Int] = [:]
    var lastPlayed: [String: Date] = [:]
    var stats = ListeningStats()

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        roots = try c.decodeIfPresent([LibraryRoot].self, forKey: .roots) ?? []
        items = try c.decodeIfPresent([MediaItem].self, forKey: .items) ?? []
        positions = try c.decodeIfPresent([String: Double].self, forKey: .positions) ?? [:]
        playCounts = try c.decodeIfPresent([String: Int].self, forKey: .playCounts) ?? [:]
        lastPlayed = try c.decodeIfPresent([String: Date].self, forKey: .lastPlayed) ?? [:]
        stats = try c.decodeIfPresent(ListeningStats.self, forKey: .stats) ?? ListeningStats()
    }
}

@MainActor
final class MediaLibrary: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var audio: [MediaItem] = []
    @Published private(set) var video: [MediaItem] = []
    @Published private(set) var roots: [LibraryRoot] = []
    @Published private(set) var isIndexing = false
    @Published private(set) var indexDone = 0
    @Published private(set) var indexTotal = 0
    @Published private(set) var loaded = false
    @Published private(set) var stats = ListeningStats()

    private var byID: [String: MediaItem] = [:]
    private var rootsByID: [String: LibraryRoot] = [:]
    private var positions: [String: Double] = [:]
    private var playCounts: [String: Int] = [:]
    private var lastPlayedDates: [String: Date] = [:]
    private var indexTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var pendingScan = false
    private let indexer = FileIndexer()
    private let access = FileAccessManager.shared
    private let eco = EcoCore.shared
    private let fileURL: URL
    private var bag = Set<AnyCancellable>()

    init(fileURL: URL = FileManagerService.supportDir.appendingPathComponent("library.json")) {
        self.fileURL = fileURL
        eco.profileChanged.sink { [weak self] _ in
            guard let self = self else { return }
            if self.pendingScan && self.eco.policy.indexing { self.pendingScan = false; self.scanAll() }
        }.store(in: &bag)
        access.onBookmarkRefreshed = { [weak self] id, data in
            guard let self = self, let i = self.roots.firstIndex(where: { $0.id == id }) else { return }
            self.roots[i].bookmark = data
            self.rootsByID[id] = self.roots[i]
            self.scheduleSave()
        }
    }

    // MARK: Chargement / sauvegarde
    func load() async {
        let url = fileURL
        let snap: LibrarySnapshot = await Task.detached(priority: .userInitiated) {
            guard let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(LibrarySnapshot.self, from: d) else { return LibrarySnapshot() }
            return s
        }.value
        roots = snap.roots
        if !roots.contains(where: { $0.id == LibraryRoot.appRootID }) { roots.insert(LibraryRoot.appRoot(), at: 0) }
        positions = snap.positions; playCounts = snap.playCounts; lastPlayedDates = snap.lastPlayed; stats = snap.stats
        rootsByID = Dictionary(uniqueKeysWithValues: roots.map { ($0.id, $0) })
        applyItems(snap.items)
        loaded = true
    }

    private func applyItems(_ new: [MediaItem]) {
        let sorted = new.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        items = sorted
        byID = Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        audio = sorted.filter { $0.kind == .audio }
        video = sorted.filter { $0.kind == .video }
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self = self else { return }
            self.saveNow()
        }
    }

    func saveNow() {
        var snap = LibrarySnapshot()
        snap.roots = roots; snap.items = items; snap.positions = positions
        snap.playCounts = playCounts; snap.lastPlayed = lastPlayedDates; snap.stats = stats
        let url = fileURL
        Task.detached(priority: .utility) {
            if let d = try? JSONEncoder().encode(snap) { try? d.write(to: url, options: .atomic) }
        }
    }

    // MARK: Accès
    func item(id: String) -> MediaItem? { byID[id] }
    func url(for item: MediaItem) -> URL? { access.url(for: item.locator, root: rootsByID[item.locator.rootID]) }
    func position(for item: MediaItem) -> Double { positions[item.id] ?? 0 }
    func setPosition(_ s: Double, for item: MediaItem) {
        positions[item.id] = s > 5 ? s : nil
        scheduleSave()
    }
    func playCount(for item: MediaItem) -> Int { playCounts[item.id] ?? 0 }
    func lastPlayed(for item: MediaItem) -> Date? { lastPlayedDates[item.id] }
    func recordPlay(_ item: MediaItem) {
        playCounts[item.id, default: 0] += 1
        lastPlayedDates[item.id] = Date()
        stats.tracksPlayed += 1
        scheduleSave()
    }
    func addListening(seconds: Double) {
        guard seconds > 0 else { return }
        stats.totalSeconds += seconds
        scheduleSave()
    }
    var recentlyPlayed: [MediaItem] {
        Array(items.compactMap { i in lastPlayedDates[i.id].map { (i, $0) } }.sorted { $0.1 > $1.1 }.prefix(10).map { $0.0 })
    }

    // MARK: Ajout
    func addFolder(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let bm = try? FileAccessManager.makeBookmark(for: url) else { return }
        let root = LibraryRoot(id: UUID().uuidString, name: url.lastPathComponent, kind: .folder, bookmark: bm, addedAt: Date())
        roots.append(root); rootsByID[root.id] = root
        scheduleSave()
        scanAll()
    }

    func addFiles(_ urls: [URL], copy: Bool) {
        Task { [weak self] in
            guard let self = self else { return }
            var added: [MediaItem] = []
            var copied = false
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard let kind = MediaFormats.kind(forExtension: url.pathExtension) else { continue }
                if copy {
                    let ok = (try? await Task.detached { try FileManagerService.shared.importCopy(from: url, kind: kind) }.value) != nil
                    if ok { copied = true }
                } else if let bm = try? FileAccessManager.makeBookmark(for: url) {
                    let root = LibraryRoot(id: UUID().uuidString, name: url.lastPathComponent, kind: .file, bookmark: bm, addedAt: Date())
                    let meta = await MetadataManager.read(url: url, kind: kind)
                    let loc = Locator(rootID: root.id, path: url.lastPathComponent)
                    let size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                    self.roots.append(root); self.rootsByID[root.id] = root
                    added.append(self.makeItem(loc, kind, meta, size, nil, fallbackName: url.deletingPathExtension().lastPathComponent))
                }
            }
            if !added.isEmpty { self.merge(added) }
            if copied { self.scanAll() }
            self.scheduleSave()
        }
    }

    private func makeItem(_ loc: Locator, _ kind: MediaKind, _ m: MediaMetadata, _ size: Int64, _ mod: Date?, fallbackName: String) -> MediaItem {
        let t = (m.title ?? "").trimmingCharacters(in: .whitespaces)
        return MediaItem(id: MediaItem.makeID(loc), locator: loc, kind: kind, title: t.isEmpty ? fallbackName : t,
                         artist: m.artist, album: m.album, duration: m.duration, fileSize: size, modified: mod, addedAt: Date())
    }

    private func merge(_ new: [MediaItem]) {
        var dict = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for n in new {
            var item = n
            if let old = dict[n.id] { item.addedAt = old.addedAt }
            dict[n.id] = item
        }
        applyItems(Array(dict.values))
        scheduleSave()
    }

    // MARK: Retrait / suppression
    func remove(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let removedFileRoots = items.filter { ids.contains($0.id) && rootsByID[$0.locator.rootID]?.kind == .file }.map { $0.locator.rootID }
        applyItems(items.filter { !ids.contains($0.id) })
        for r in removedFileRoots { roots.removeAll { $0.id == r }; rootsByID[r] = nil; access.forget(rootID: r) }
        for id in ids { positions[id] = nil; playCounts[id] = nil; lastPlayedDates[id] = nil }
        scheduleSave()
    }

    /// Supprime réellement le fichier (dossier MediaBox uniquement). Retourne le nombre supprimé.
    @discardableResult
    func deleteFiles(ids: Set<String>) -> Int {
        var n = 0
        for id in ids {
            guard let it = byID[id], it.locator.rootID == LibraryRoot.appRootID, let u = url(for: it) else { continue }
            if (try? FileManagerService.shared.delete(u)) != nil { n += 1 }
        }
        remove(ids: ids)
        return n
    }

    func isManaged(_ item: MediaItem) -> Bool { item.locator.rootID == LibraryRoot.appRootID }

    // MARK: Indexation
    func scanAll() {
        guard indexTask == nil else { return }
        indexTask = Task { [weak self] in
            await self?.runScan()
            self?.indexTask = nil
        }
    }

    func cancelIndexing() {
        indexTask?.cancel(); indexTask = nil
        isIndexing = false
    }

    private func runScan() async {
        guard eco.policy.indexing else { pendingScan = true; return }
        isIndexing = true
        defer { isIndexing = false }
        for root in roots where root.kind != .file {
            if Task.isCancelled { return }
            guard let base = access.rootURL(for: root) else { continue }
            var known: [String: Int64] = [:]
            for i in items where i.locator.rootID == root.id { known[i.locator.path] = i.fileSize }
            let result = await indexer.enumerate(base: base, known: known)
            if Task.isCancelled { return }
            if result.complete {
                let gone = Set(items.filter { $0.locator.rootID == root.id && !result.seen.contains($0.locator.path) }.map { $0.id })
                if !gone.isEmpty { remove(ids: gone) }
            }
            await ingest(result.candidates, rootID: root.id)
        }
    }

    private func ingest(_ candidates: [FileIndexer.Candidate], rootID: String) async {
        indexDone = 0; indexTotal = candidates.count
        var index = 0
        while index < candidates.count {
            if Task.isCancelled { return }
            if !eco.policy.indexing { pendingScan = true; return }
            let end = min(index + 25, candidates.count)
            let batch = Array(candidates[index..<end])
            let conc = max(1, eco.policy.indexingConcurrency)
            var built: [MediaItem] = []
            var i = 0
            while i < batch.count {
                let chunk = Array(batch[i..<min(i + conc, batch.count)])
                let metas = await withTaskGroup(of: (Int, MediaMetadata).self) { group -> [(Int, MediaMetadata)] in
                    for (n, c) in chunk.enumerated() {
                        group.addTask { (n, await MetadataManager.read(url: c.url, kind: c.kind)) }
                    }
                    var out: [(Int, MediaMetadata)] = []
                    for await r in group { out.append(r) }
                    return out
                }
                for (n, m) in metas {
                    let c = chunk[n]
                    let loc = Locator(rootID: rootID, path: c.path)
                    let fallback = ((c.path as NSString).lastPathComponent as NSString).deletingPathExtension
                    built.append(makeItem(loc, c.kind, m, c.size, c.modified, fallbackName: fallback))
                }
                i += conc
            }
            merge(built)
            index = end
            indexDone = end
            MemoryManager.shared.checkBudget(reason: "indexation")
            await Task.yield()
        }
    }
}
