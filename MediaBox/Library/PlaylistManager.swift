import Foundation

enum SmartRule: String, Codable, CaseIterable, Identifiable {
    case recentlyAdded, mostPlayed, recentlyPlayed, neverPlayed, longTracks, needsAttention
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recentlyAdded: return "Ajoutés récemment"
        case .mostPlayed: return "Les plus écoutés"
        case .recentlyPlayed: return "Écoutés récemment"
        case .neverPlayed: return "Jamais écoutés"
        case .longTracks: return "Longs titres (> 10 min)"
        case .needsAttention: return "Métadonnées à corriger"
        }
    }
    var icon: String {
        switch self {
        case .recentlyAdded: return "sparkles"
        case .mostPlayed: return "flame"
        case .recentlyPlayed: return "clock"
        case .neverPlayed: return "eye.slash"
        case .longTracks: return "hourglass"
        case .needsAttention: return "wrench.and.screwdriver"
        }
    }
}

struct Playlist: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var itemIDs: [String] = []
    var created = Date()
}

@MainActor
final class PlaylistManager: ObservableObject {
    @Published private(set) var playlists: [Playlist] = []
    private let fileURL: URL

    init(fileURL: URL = FileManagerService.supportDir.appendingPathComponent("playlists.json")) {
        self.fileURL = fileURL
        if let d = try? Data(contentsOf: fileURL), let p = try? JSONDecoder().decode([Playlist].self, from: d) { playlists = p }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(playlists) { try? d.write(to: fileURL, options: .atomic) }
    }

    @discardableResult
    func create(name: String) -> Playlist {
        let p = Playlist(name: name.isEmpty ? "Nouvelle playlist" : name)
        playlists.append(p); save(); return p
    }
    func rename(_ id: UUID, to name: String) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[i].name = name; save()
    }
    func delete(_ id: UUID) { playlists.removeAll { $0.id == id }; save() }
    func add(_ itemID: String, to id: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == id }), !playlists[i].itemIDs.contains(itemID) else { return }
        playlists[i].itemIDs.append(itemID); save()
    }
    func remove(at offsets: IndexSet, from id: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[i].itemIDs.remove(atOffsets: offsets); save()
    }
    func move(from: IndexSet, to: Int, in id: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[i].itemIDs.move(fromOffsets: from, toOffset: to); save()
    }
    func purge(ids: Set<String>) {
        var changed = false
        for i in playlists.indices {
            let before = playlists[i].itemIDs.count
            playlists[i].itemIDs.removeAll { ids.contains($0) }
            if playlists[i].itemIDs.count != before { changed = true }
        }
        if changed { save() }
    }

    func items(of playlist: Playlist, in library: MediaLibrary) -> [MediaItem] {
        playlist.itemIDs.compactMap { library.item(id: $0) }
    }

    func items(for rule: SmartRule, in library: MediaLibrary) -> [MediaItem] {
        let audio = library.audio
        switch rule {
        case .recentlyAdded: return Array(audio.sorted { $0.addedAt > $1.addedAt }.prefix(50))
        case .mostPlayed: return Array(audio.filter { library.playCount(for: $0) > 0 }.sorted { library.playCount(for: $0) > library.playCount(for: $1) }.prefix(50))
        case .recentlyPlayed: return Array(audio.compactMap { i in library.lastPlayed(for: i).map { (i, $0) } }.sorted { $0.1 > $1.1 }.prefix(50).map { $0.0 })
        case .neverPlayed: return audio.filter { library.playCount(for: $0) == 0 }
        case .longTracks: return audio.filter { $0.duration > 600 }
        case .needsAttention: return audio.filter { $0.hasMetadataGap }
        }
    }
}
