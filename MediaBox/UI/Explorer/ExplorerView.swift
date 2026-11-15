import SwiftUI

struct ServiceCard: View {
    let service: MediaService
    var body: some View {
        let c = Color(red: service.rgb.0, green: service.rgb.1, blue: service.rgb.2)
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(c.opacity(0.22)).frame(width: 46, height: 46)
                Circle().strokeBorder(c.opacity(0.55), lineWidth: 1).frame(width: 46, height: 46)
                Image(systemName: service.symbol).font(.title3).foregroundColor(c)
            }
            Text(service.name).font(.headline)
            Text(service.supportsAPIDownload ? "Lecture + téléchargement officiel" : "Lecture officielle")
                .font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard()
        .contentShape(Rectangle())
    }
}

struct ExplorerView: View {
    @EnvironmentObject var browser: BrowserManager
    @EnvironmentObject var downloads: DownloadManager
    @State private var query = ""
    @State private var openBrowser = false
    @State private var info: MediaService?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Rechercher ou saisir une adresse", text: $query)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go)
                            .onSubmit { go(query) }
                        Button { if let t = UIPasteboard.general.string { query = t; go(t) } } label: { Image(systemName: "doc.on.clipboard") }
                            .accessibilityLabel("Coller un lien")
                    }
                    .padding(14).glassCard(radius: 18)

                    Text("Services").font(.title3.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(MediaService.allCases) { s in
                            ServiceCard(service: s)
                                .onTapGesture { open(s.homeURL) }
                                .contextMenu {
                                    Button { open(s.homeURL) } label: { Label("Ouvrir dans MediaBox", systemImage: "safari") }
                                    Button { openExternal(s.homeURL) } label: { Label("Ouvrir dans l'app officielle", systemImage: "arrow.up.forward.app") }
                                    Button { info = s } label: { Label("Ce que MediaBox peut faire", systemImage: "info.circle") }
                                }
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    Text("Appui long sur un service pour ses options. Les fichiers ne sont téléchargeables que lorsque la plateforme l'autorise officiellement ; sinon MediaBox lit le contenu via le site officiel.")
                        .font(.footnote).foregroundColor(.secondary)
                    if let last = browser.history.entries.first {
                        Button { if let u = URL(string: last.url) { open(u) } } label: {
                            HStack { Image(systemName: "clock.arrow.circlepath"); Text(last.title).lineLimit(1); Spacer() }
                                .padding(14).glassCard(radius: 18)
                        }.buttonStyle(.plain)
                    }
                }.padding()
            }
            .navigationTitle("Explorer")
            .navigationDestination(isPresented: $openBrowser) { BrowserView() }
            .sheet(item: $info) { s in ServiceInfoSheet(service: s) }
        }
    }

    private func go(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        browser.go(t)
        openBrowser = true
    }
    private func open(_ url: URL) { browser.open(url); openBrowser = true }
    private func openExternal(_ url: URL) {
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { ok in
            if !ok { Task { @MainActor in open(url) } }
        }
    }
}

struct ServiceInfoSheet: View {
    let service: MediaService
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                GSection("Lecture") { Text(service.playbackNote) }
                GSection("Téléchargement") {
                    switch service.download {
                    case .none(let why): Label(why, systemImage: "lock.fill")
                    case .officialAPI(let note): Label(note, systemImage: "checkmark.seal.fill")
                    }
                }
                if service.supportsAPIDownload {
                    GSection("Configuration") { Text("Ajoute ton jeton personnel dans Réglages > Services.") }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(service.name)
            .toolbar { Button("Fermer") { dismiss() } }
        }
    }
}
