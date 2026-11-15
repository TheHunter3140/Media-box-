import SwiftUI

struct BrowserView: View {
    @EnvironmentObject var browser: BrowserManager
    @EnvironmentObject var downloads: DownloadManager
    @State private var message: String?
    @State private var busy = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { browser.back() } label: { Image(systemName: "chevron.left") }.disabled(!browser.canGoBack).accessibilityLabel("Retour")
                Button { browser.forward() } label: { Image(systemName: "chevron.right") }.disabled(!browser.canGoForward).accessibilityLabel("Avancer")
                TextField("Adresse ou recherche", text: $browser.addressText)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.webSearch).focused($focused)
                    .onSubmit { browser.go(browser.addressText); focused = false }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .glassCard(radius: 14)
                Button { browser.reload() } label: { Image(systemName: browser.isLoading ? "xmark" : "arrow.clockwise") }.accessibilityLabel("Actualiser")
            }.padding(.horizontal, 12).padding(.vertical, 8)
            if browser.isLoading { ProgressView(value: browser.progress).padding(.horizontal, 12) }
            if let s = browser.currentService { serviceBanner(s) }
            if let wv = browser.webView {
                WebViewContainer(webView: wv)
            } else {
                Spacer(); ProgressView(); Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { browser.pageShown() }
        .onDisappear { browser.pageHidden() }
        .sheet(item: $browser.pendingDownload) { file in
            DetectedFileSheet(file: file) { dest in
                Task {
                    await browser.copyCookies(for: file.url)
                    handle(downloads.enqueue(url: file.url, name: file.filename, destination: dest))
                }
            }.presentationDetents([.medium])
        }
        .alert("Téléchargement", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    @ViewBuilder
    private func serviceBanner(_ s: MediaService) -> some View {
        let c = Color(red: s.rgb.0, green: s.rgb.1, blue: s.rgb.2)
        HStack(spacing: 10) {
            Image(systemName: s.symbol).foregroundColor(c)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name).font(.footnote.weight(.semibold))
                switch s.download {
                case .none: Text("Lecture officielle. Téléchargement non pris en charge.").font(.caption2).foregroundColor(.secondary)
                case .officialAPI: Text("Téléchargement possible si l'auteur l'autorise.").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            if s.supportsAPIDownload, let u = browser.webView?.url {
                Button(busy ? "…" : "Télécharger") {
                    busy = true
                    Task { message = await ServiceDownloader.start(url: u, downloads: downloads); busy = false }
                }.font(.footnote.weight(.semibold)).disabled(busy)
            }
        }
        .padding(10).glassCard(radius: 14).padding(.horizontal, 12).padding(.bottom, 6)
    }

    private func handle(_ r: EnqueueResult) {
        switch r {
        case .added: message = "Ajouté à la file de téléchargements."
        case .duplicate(let m): message = m
        case .alreadyActive: message = "Ce fichier est déjà dans la file."
        }
    }
}

struct DetectedFileSheet: View {
    let file: DetectedFile
    let onDownload: (DownloadDestination) -> Void
    @EnvironmentObject var browser: BrowserManager
    @Environment(\.dismiss) private var dismiss
    @State private var dest: DownloadDestination = .auto

    var body: some View {
        NavigationStack {
            Form {
                GSection("Fichier détecté") {
                    Text(file.filename)
                    Text(file.url.absoluteString).font(.caption).foregroundColor(.secondary).lineLimit(3)
                }
                GSection("Destination") {
                    Picker("Dossier", selection: $dest) { ForEach(DownloadDestination.allCases) { Text($0.label).tag($0) } }
                }
                GSection {
                    Button("Télécharger") { onDownload(dest); dismiss() }
                    Button("Ignorer et ouvrir dans la page", role: .cancel) { browser.ignoreDetected(); dismiss() }
                }
                GSection { Text("Télécharge uniquement des fichiers auxquels tu as légitimement accès et dont les droits te le permettent.").font(.footnote).foregroundColor(.secondary) }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Télécharger ?")
        }
    }
}
