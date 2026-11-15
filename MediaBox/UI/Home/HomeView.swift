import SwiftUI

struct HomeView: View {
    @EnvironmentObject var library: MediaLibrary
    @EnvironmentObject var playlists: PlaylistManager
    @EnvironmentObject var playback: PlaybackController
    @EnvironmentObject var eco: EcoCore
    @EnvironmentObject var downloads: DownloadManager
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if eco.profile != .normal {
                        HStack {
                            Image(systemName: "leaf.fill").foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Profil : \(eco.profile.label)").font(.subheadline.weight(.semibold))
                                Text(eco.reason).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }.padding(12).surface()
                    }
                    if library.isIndexing {
                        HStack {
                            ProgressView()
                            Text("Indexation \(library.indexDone)/\(library.indexTotal)").font(.footnote).foregroundColor(.secondary)
                        }
                    }
                    insights
                    if !library.recentlyPlayed.isEmpty {
                        section("Reprendre") {
                            ForEach(library.recentlyPlayed.prefix(5)) { item in
                                Button { playback.play([item]) } label: {
                                    HStack { ArtworkView(item: item, size: 44); VStack(alignment: .leading) {
                                        Text(item.title).lineLimit(1); Text(item.displayArtist).font(.caption).foregroundColor(.secondary)
                                    }; Spacer(); Image(systemName: "play.circle").foregroundColor(Theme.accent) }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    section("Playlists intelligentes") {
                        ForEach(SmartRule.allCases) { rule in
                            let list = playlists.items(for: rule, in: library)
                            NavigationLink { SmartPlaylistView(rule: rule) } label: {
                                HStack { Image(systemName: rule.icon).frame(width: 28).foregroundColor(Theme.accent)
                                    Text(rule.title); Spacer(); Text("\(list.count)").foregroundColor(.secondary) }
                            }.buttonStyle(.plain)
                        }
                    }
                    if library.items.isEmpty && library.loaded {
                        VStack(spacing: 8) {
                            Image(systemName: "tray.and.arrow.down").font(.largeTitle).foregroundColor(.secondary)
                            Text("Ajoute de la musique ou des vidéos depuis l'onglet Bibliothèque, ou dépose-les dans Fichiers > Sur mon iPhone > MediaBox.")
                                .font(.footnote).multilineTextAlignment(.center).foregroundColor(.secondary)
                            Button("Ouvrir la bibliothèque") { coordinator.selectedTab = .library }
                        }.frame(maxWidth: .infinity).padding()
                    }
                }.padding()
            }
            .navigationTitle("MediaBox")
        }
    }

    private var insights: some View {
        HStack(spacing: 10) {
            stat("\(library.audio.count)", "titres")
            stat("\(library.video.count)", "vidéos")
            stat(Format.time(library.stats.totalSeconds), "écoute")
            stat("\(downloads.history.entries.filter { $0.success }.count)", "téléch.")
        }
    }
    private func stat(_ v: String, _ l: String) -> some View {
        VStack { Text(v).font(.headline); Text(l).font(.caption2).foregroundColor(.secondary) }
            .frame(maxWidth: .infinity).padding(.vertical, 10).surface(radius: 12)
    }
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) { content() }.padding(12).frame(maxWidth: .infinity, alignment: .leading).surface()
        }
    }
}

struct SmartPlaylistView: View {
    let rule: SmartRule
    @EnvironmentObject var library: MediaLibrary
    @EnvironmentObject var playlists: PlaylistManager
    @EnvironmentObject var playback: PlaybackController

    var body: some View {
        let items = playlists.items(for: rule, in: library)
        List {
            if items.isEmpty { Text("Aucun élément.").foregroundColor(.secondary) }
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                Button { playback.play(items, startAt: idx) } label: { MediaRow(item: item) }.buttonStyle(.plain)
            }
        }
        .navigationTitle(rule.title)
        .toolbar { if !items.isEmpty { Button { playback.play(items, shuffle: true) } label: { Image(systemName: "shuffle") } } }
    }
}
