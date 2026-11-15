import SwiftUI

struct BrowserView: View {
    @EnvironmentObject var browser: BrowserManager
    @EnvironmentObject var downloads: DownloadManager
    @EnvironmentObject var settings: AppSettings
    @State private var message: String?
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
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Button { browser.reload() } label: { Image(systemName: browser.isLoading ? "xmark" : "arrow.clockwise") }.accessibilityLabel("Actualiser")
            }.padding(.horizontal, 12).padding(.vertical, 8)
            if browser.isLoading { ProgressView(value: browser.progress).padding(.horizontal, 12) }
            if browser.isYouTubePage {
                Label("YouTube : lecture via le service officiel. Les téléchargements protégés ne sont pas disponibles dans MediaBox.", systemImage: "info.circle")
                    .font(.caption).padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Color.yellow.opacity(0.16))
            }
            if let wv = browser.webView {
                WebViewContainer(webView: wv)
            } else {
                Spacer(); ProgressView(); Spacer()
            }
        }
        .onAppear { browser.pageShown() }
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
                Section("Fichier détecté") {
                    Text(file.filename)
                    Text(file.url.absoluteString).font(.caption).foregroundColor(.secondary).lineLimit(3)
                }
                Section("Destination") {
                    Picker("Dossier", selection: $dest) { ForEach(DownloadDestination.allCases) { Text($0.label).tag($0) } }
                }
                Section {
                    Button("Télécharger") { onDownload(dest); dismiss() }
                    Button("Ignorer et ouvrir dans la page", role: .cancel) { browser.ignoreDetected(); dismiss() }
                }
                Section { Text("Télécharge uniquement des fichiers auxquels tu as légitimement accès et dont les droits te le permettent.").font(.footnote).foregroundColor(.secondary) }
            }
            .navigationTitle("Télécharger ?")
        }
    }
}
