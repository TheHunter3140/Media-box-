import SwiftUI

struct MediaRow: View {
    let item: MediaItem
    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(item: item, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).lineLimit(1)
                Text(item.kind == .audio ? item.displayArtist : Format.bytes(item.fileSize))
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            if item.duration > 0 { Text(Format.time(item.duration)).font(.caption).monospacedDigit().foregroundColor(.secondary) }
        }
        .contentShape(Rectangle())
    }
}

struct LibraryView: View {
    @EnvironmentObject var library: MediaLibrary
    @EnvironmentObject var playlists: PlaylistManager
    @EnvironmentObject var playback: PlaybackController
    @EnvironmentObject var settings: AppSettings
    enum Segment: String, CaseIterable { case music = "Musique", video = "Vidéos", playlists = "Playlists" }
    @State private var segment: Segment = .music
    @State private var search = ""
    @State private var picker: DocumentPicker.Mode?
    @State private var copyMode = false
    @State private var newPlaylistName = ""
    @State private var showNewPlaylist = false
    @State private var pendingRemoval: MediaItem?

    private var items: [MediaItem] {
        let base = segment == .video ? library.video : library.audio
        guard !search.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(search) || ($0.artist ?? "").localizedCaseInsensitiveContains(search) || ($0.album ?? "").localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $segment) { ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).padding(.horizontal).padding(.bottom, 6)
                if segment == .playlists { playlistList } else { mediaList }
            }
            .navigationTitle("Bibliothèque")
            .searchable(text: $search, prompt: "Rechercher")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { copyMode = false; picker = .files } label: { Label("Ajouter des fichiers (accès direct)", systemImage: "doc.badge.plus") }
                        Button { picker = .folder } label: { Label("Ajouter un dossier (accès direct)", systemImage: "folder.badge.plus") }
                        Button { copyMode = true; picker = .files } label: { Label("Importer une copie dans MediaBox", systemImage: "square.and.arrow.down") }
                        Divider()
                        Button { library.scanAll() } label: { Label("Réindexer", systemImage: "arrow.clockwise") }
                    } label: { Image(systemName: "plus") }
                }
                if segment != .playlists && !items.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { settings.tap(); playback.play(items, shuffle: true) } label: { Image(systemName: "shuffle") }
                    }
                }
            }
            .sheet(item: Binding(get: { picker.map { PickerID(mode: $0) } }, set: { if $0 == nil { picker = nil } })) { p in
                DocumentPicker(mode: p.mode) { urls in
                    if p.mode == .folder { urls.forEach { library.addFolder($0) } } else { library.addFiles(urls, copy: copyMode) }
                }
            }
            .alert("Nouvelle playlist", isPresented: $showNewPlaylist) {
                TextField("Nom", text: $newPlaylistName)
                Button("Créer") { playlists.create(name: newPlaylistName); newPlaylistName = "" }
                Button("Annuler", role: .cancel) {}
            }
            .confirmationDialog("Retirer de la bibliothèque ?", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible) {
                if let it = pendingRemoval {
                    Button("Retirer de la bibliothèque") { library.remove(ids: [it.id]); playlists.purge(ids: [it.id]) }
                    if library.isManaged(it) {
                        Button("Supprimer le fichier de l'iPhone", role: .destructive) { library.deleteFiles(ids: [it.id]); playlists.purge(ids: [it.id]) }
                    }
                }
            } message: { Text("Les fichiers situés hors du dossier MediaBox ne sont jamais supprimés.") }
        }
    }

    private struct PickerID: Identifiable { let mode: DocumentPicker.Mode; var id: Int { mode == .files ? 0 : 1 } }

    private var mediaList: some View {
        List {
            if library.isIndexing { HStack { ProgressView(); Text("Indexation \(library.indexDone)/\(library.indexTotal)").font(.footnote) } }
            if items.isEmpty && !library.isIndexing {
                Text(search.isEmpty ? "Aucun média. Utilise + pour ajouter des fichiers ou un dossier." : "Aucun résultat.").foregroundColor(.secondary)
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                Button { settings.tap(); playback.play(items, startAt: idx) } label: { MediaRow(item: item) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { playback.playNext(item) } label: { Label("Lire ensuite", systemImage: "text.insert") }
                        Menu("Ajouter à une playlist") {
                            ForEach(playlists.playlists) { p in Button(p.name) { playlists.add(item.id, to: p.id) } }
                        }
                        Button(role: .destructive) { pendingRemoval = item } label: { Label("Retirer…", systemImage: "trash") }
                    }
            }
        }
        .listStyle(.plain)
    }

    private var playlistList: some View {
        List {
            Button { showNewPlaylist = true } label: { Label("Nouvelle playlist", systemImage: "plus.circle") }
            ForEach(playlists.playlists) { p in
                NavigationLink { PlaylistDetailView(playlistID: p.id) } label: {
                    HStack { Text(p.name); Spacer(); Text("\(p.itemIDs.count)").foregroundColor(.secondary) }
                }
            }
            .onDelete { idx in idx.map { playlists.playlists[$0].id }.forEach { playlists.delete($0) } }
        }.listStyle(.plain)
    }
}

struct PlaylistDetailView: View {
    let playlistID: UUID
    @EnvironmentObject var playlists: PlaylistManager
    @EnvironmentObject var library: MediaLibrary
    @EnvironmentObject var playback: PlaybackController

    var body: some View {
        if let p = playlists.playlists.first(where: { $0.id == playlistID }) {
            let items = playlists.items(of: p, in: library)
            List {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    Button { playback.play(items, startAt: idx) } label: { MediaRow(item: item) }.buttonStyle(.plain)
                }
                .onDelete { playlists.remove(at: $0, from: playlistID) }
                .onMove { playlists.move(from: $0, to: $1, in: playlistID) }
            }
            .navigationTitle(p.name)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    EditButton()
                    Button { playback.play(items, shuffle: true) } label: { Image(systemName: "shuffle") }.disabled(items.isEmpty)
                    Button { playback.play(items) } label: { Image(systemName: "play.fill") }.disabled(items.isEmpty)
                }
            }
        } else { Text("Playlist introuvable") }
    }
}
