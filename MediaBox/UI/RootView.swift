import SwiftUI

struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var playback: PlaybackController
    @EnvironmentObject var eco: EcoCore

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeView().tabItem { Label("Accueil", systemImage: "house") }.tag(AppTab.home)
            LibraryView().tabItem { Label("Bibliothèque", systemImage: "music.note.list") }.tag(AppTab.library)
            BrowserView().tabItem { Label("Navigateur", systemImage: "safari") }.tag(AppTab.browser)
            DownloadsView().tabItem { Label("Téléchargements", systemImage: "arrow.down.circle") }.tag(AppTab.downloads)
            SettingsView().tabItem { Label("Réglages", systemImage: "gearshape") }.tag(AppTab.settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { MiniPlayerView() }
        .sheet(isPresented: $playback.playerPresented) { PlayerView() }
        .fullScreenCover(isPresented: $playback.videoPresented) { VideoPlayerScreen() }
        .alert("Lecture", isPresented: Binding(get: { playback.errorMessage != nil }, set: { if !$0 { playback.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(playback.errorMessage ?? "") }
        .transaction { if !eco.policy.animations { $0.animation = nil } }
    }
}

struct MiniPlayerView: View {
    @EnvironmentObject var playback: PlaybackController
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 12) {
            if let c = playback.current {
                ArtworkView(item: c, size: 40, pixel: 100)
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(playback.active == .video ? "Vidéo" : c.displayArtist).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                Button { settings.tap(); playback.toggle() } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").font(.title3).frame(width: 44, height: 44)
                }.accessibilityLabel(playback.isPlaying ? "Pause" : "Lecture")
                Button { settings.tap(); playback.next() } label: {
                    Image(systemName: "forward.fill").font(.body).frame(width: 40, height: 44)
                }.accessibilityLabel("Suivant")
            } else {
                Image(systemName: "waveform").foregroundColor(.secondary).frame(width: 40, height: 40)
                Text("Aucune lecture").font(.subheadline).foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .surface()
        .padding(.horizontal, 10).padding(.bottom, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard playback.current != nil else { return }
            if playback.active == .video { playback.videoPresented = true } else { playback.playerPresented = true }
        }
    }
}
