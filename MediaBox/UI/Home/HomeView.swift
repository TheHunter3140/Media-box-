import SwiftUI

struct HomeView: View {
    @EnvironmentObject var library: MediaLibrary
    @EnvironmentObject var playlists: PlaylistManager
    @EnvironmentObject var playback: PlaybackController
    @EnvironmentObject var eco: EcoCore
    @EnvironmentObject var downloads: DownloadManager
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var settings: AppSettings

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    if eco.profile != .normal { ecoBanner }
                    stats
                    servicesSection
                    quickActions
                    if !library.recentlyPlayed.isEmpty { recentSection }
                    smartPlaylists
                    if library.isIndexing {
                        HStack(spacing: 10) { ProgressView(); Text("Indexation \(library.indexDone)/\(library.indexTotal)").font(.footnote).foregroundStyle(.secondary) }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).glassSurface()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.heroGradient)
            Circle().fill(.white.opacity(0.10)).frame(width: 180).blur(radius: 1).offset(x: 220, y: -65)
            Circle().fill(.purple.opacity(0.30)).frame(width: 130).blur(radius: 28).offset(x: 190, y: 90)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("MEDIABOX", systemImage: "waveform")
                        .font(.caption.weight(.bold)).tracking(2).foregroundStyle(.white.opacity(0.84))
                    Spacer()
                    Image(systemName: "sparkles").font(.title3).foregroundStyle(.white.opacity(0.9))
                }
                Text("Tout ton\nunivers média.")
                    .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Écoute, regarde, organise et retrouve tes contenus au même endroit.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.82)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button { coordinator.selectedTab = .library } label: {
                        Label("Ma bibliothèque", systemImage: "play.fill").font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 11).background(.white, in: Capsule()).foregroundStyle(Color.black.opacity(0.85))
                    }
                    Button { coordinator.selectedTab = .browser } label: {
                        Image(systemName: "safari").font(.subheadline.weight(.semibold)).frame(width: 42, height: 42)
                            .background(.white.opacity(0.16), in: Circle()).overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1)).foregroundStyle(.white)
                    }.accessibilityLabel("Ouvrir le navigateur")
                }
            }.padding(22)
        }
        .frame(minHeight: 238)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .blue.opacity(0.16), radius: 20, y: 10)
    }

    private var ecoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.fill").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mode éco · \(eco.profile.label)").font(.subheadline.weight(.semibold))
                Text(eco.reason).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(14).glassSurface()
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("\(library.audio.count)", "Titres", "music.note")
            stat("\(library.video.count)", "Vidéos", "play.rectangle")
            stat("\(downloads.history.entries.filter { $0.success }.count)", "Enregistrés", "arrow.down.circle")
        }
    }
    private func stat(_ value: String, _ title: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).font(.headline).foregroundStyle(Theme.accent)
            Text(value).font(.title2.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).glassSurface()
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader("Tes plateformes", subtitle: "Ouvre les services officiels")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MediaService.all) { service in
                    Button { open(service) } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(serviceColor(service).opacity(0.15))
                                Image(systemName: service.symbol).font(.title3.weight(.semibold)).foregroundStyle(serviceColor(service))
                            }.frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(service.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(service.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(12).frame(maxWidth: .infinity, minHeight: 72)
                        .glassSurface(radius: 18)
                    }.buttonStyle(.plain)
                    .accessibilityHint("Ouvre le site officiel de \(service.name) dans le navigateur MediaBox")
                }
            }
            Text("Les plateformes restent responsables de leur lecture, de leurs comptes et de leurs options hors ligne. MediaBox n'extrait pas les flux protégés.")
                .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 2)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Accès rapide", subtitle: "Tes outils MediaBox")
            HStack(spacing: 12) {
                quickAction("Téléchargements", "arrow.down.to.line", tint: .blue) { coordinator.selectedTab = .downloads }
                quickAction("Fichiers", "folder", tint: .purple) { coordinator.selectedTab = .library }
                quickAction("Navigateur", "safari", tint: .teal) { coordinator.selectedTab = .browser }
            }
        }
    }
    private func quickAction(_ title: String, _ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol).font(.title3).foregroundStyle(tint)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
            }.frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).padding(13).glassSurface(radius: 18)
        }.buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Reprendre", subtitle: "Récemment écoutés ou regardés")
            VStack(spacing: 0) {
                ForEach(Array(library.recentlyPlayed.prefix(4).enumerated()), id: \.element.id) { index, item in
                    Button { playback.play(Array(library.recentlyPlayed.prefix(4)), startAt: index) } label: {
                        HStack(spacing: 12) {
                            ArtworkView(item: item, size: 48, pixel: 96)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1).foregroundStyle(.primary)
                                Text(item.displayArtist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Theme.accent)
                        }.padding(11).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    if index != min(library.recentlyPlayed.count, 4) - 1 { Divider().padding(.leading, 70) }
                }
            }.glassSurface(radius: 20)
        }
    }

    private var smartPlaylists: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Mix & collections", subtitle: "Listes générées depuis ta bibliothèque")
            VStack(spacing: 0) {
                ForEach(SmartRule.allCases) { rule in
                    let count = playlists.items(for: rule, in: library).count
                    NavigationLink { SmartPlaylistView(rule: rule) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: rule.icon).foregroundStyle(Theme.accent).frame(width: 30)
                            Text(rule.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                            Spacer()
                            Text("\(count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }.padding(13)
                    }
                    if rule.id != SmartRule.allCases.last?.id { Divider().padding(.leading, 54) }
                }
            }.glassSurface(radius: 20)
        }
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.weight(.bold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func open(_ service: MediaService) {
        settings.tap()
        coordinator.selectedTab = .browser
        coordinator.browser.go(service.url.absoluteString)
    }

    private func serviceColor(_ service: MediaService) -> Color {
        switch service.tintName {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "indigo": return .indigo
        case "pink": return .pink
        default: return .purple
        }
    }
}

private extension View {
    @ViewBuilder func glassSurface(radius: CGFloat = 20) -> some View {
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.primary.opacity(0.055), lineWidth: 1))
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
