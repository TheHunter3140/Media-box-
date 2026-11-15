import SwiftUI

struct ThemedRoot: View {
    @EnvironmentObject var settings: AppSettings
    var body: some View { RootView().preferredColorScheme(settings.appearance.scheme) }
}

struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var playback: PlaybackController
    @EnvironmentObject var eco: EcoCore

    var body: some View {
        ZStack {
            GlassBackground()
            Group {
                switch coordinator.selectedTab {
                case .home: HomeView()
                case .library: LibraryView()
                case .browser: ExplorerView()
                case .downloads: DownloadsView()
                case .settings: SettingsView()
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { Dock() }
        .sheet(isPresented: $playback.playerPresented) { PlayerView() }
        .fullScreenCover(isPresented: $playback.videoPresented) { VideoPlayerScreen() }
        .alert("Lecture", isPresented: Binding(get: { playback.errorMessage != nil }, set: { if !$0 { playback.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(playback.errorMessage ?? "") }
        .transaction { if !eco.policy.animations { $0.animation = nil } }
    }
}

/// Dock flottant : mini-lecteur permanent + barre d'onglets, en verre.
struct Dock: View {
    var body: some View {
        VStack(spacing: 8) {
            MiniPlayerView()
            TabBarView()
        }
        .padding(.horizontal, 12).padding(.bottom, 4)
    }
}

struct TabBarView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var settings: AppSettings
    private let tabs: [(AppTab, String, String)] = [
        (.home, "Accueil", "house.fill"), (.library, "Biblio", "music.note.list"),
        (.browser, "Explorer", "globe"), (.downloads, "Télécharg.", "arrow.down.circle.fill"),
        (.settings, "Réglages", "gearshape.fill")
    ]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { tab, label, icon in
                let selected = coordinator.selectedTab == tab
                Button { settings.tap(); coordinator.selectedTab = tab } label: {
                    VStack(spacing: 2) {
                        Image(systemName: icon).font(.system(size: 19, weight: .semibold))
                        Text(label).font(.system(size: 10, weight: .medium)).lineLimit(1)
                    }
                    .foregroundStyle(selected ? AnyShapeStyle(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.secondary))
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background {
                        if selected { Capsule().fill(Theme.accent.opacity(0.16)).overlay(Capsule().strokeBorder(Theme.edge.opacity(0.5), lineWidth: 0.5)) }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(5)
        .glassSurface(radius: 30)
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
        .padding(.horizontal, 12).padding(.vertical, 5)
        .glassSurface(radius: 26)
        .contentShape(Rectangle())
        .onTapGesture {
            guard playback.current != nil else { return }
            if playback.active == .video { playback.videoPresented = true } else { playback.playerPresented = true }
        }
    }
}
