import SwiftUI

struct DownloadRow: View {
    @ObservedObject var task: DownloadTask
    let manager: DownloadManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.filename).lineLimit(1).font(.subheadline.weight(.semibold))
                Spacer()
                Text(task.state.label).font(.caption).foregroundColor(.secondary)
            }
            if task.state == .running || task.state == .paused {
                ProgressView(value: task.progress)
                HStack {
                    Text("\(Format.bytes(task.received)) / \(task.total > 0 ? Format.bytes(task.total) : "?")")
                    Spacer()
                    if task.state == .running && task.speed > 0 { Text("\(Format.bytes(Int64(task.speed)))/s") }
                    if let eta = task.eta, task.state == .running { Text("· \(Format.time(eta))") }
                }.font(.caption).foregroundColor(.secondary)
            }
            if let e = task.errorMessage { Text(e).font(.caption).foregroundColor(.red) }
            HStack(spacing: 18) {
                switch task.state {
                case .running, .queued:
                    Button { manager.pause(task) } label: { Label("Pause", systemImage: "pause.fill") }
                case .paused:
                    Button { manager.resume(task) } label: { Label("Reprendre", systemImage: "play.fill") }
                case .failed:
                    Button { manager.retry(task) } label: { Label("Réessayer", systemImage: "arrow.clockwise") }
                default: EmptyView()
                }
                Button(role: .destructive) { manager.cancel(task) } label: { Label("Annuler", systemImage: "xmark") }
            }.font(.caption).buttonStyle(.borderless)
        }.padding(.vertical, 4)
    }
}

struct DownloadsView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var showAdd = false
    @State private var urlText = ""
    @State private var dest: DownloadDestination = .auto
    @State private var message: String?
    @State private var duplicateURL: URL?
    @State private var addingBusy = false

    var body: some View {
        NavigationStack {
            List {
                GSection("En cours") {
                    if manager.tasks.isEmpty { Text("Aucun téléchargement.").foregroundColor(.secondary) }
                    ForEach(manager.tasks) { DownloadRow(task: $0, manager: manager) }
                }
                GSection("Historique") {
                    ForEach(manager.history.entries.prefix(50)) { e in
                        VStack(alignment: .leading) {
                            HStack { Text(e.filename).lineLimit(1); Spacer()
                                Image(systemName: e.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundColor(e.success ? .green : .orange) }
                            Text("\(e.date.formatted(date: .abbreviated, time: .shortened)) · \(Format.bytes(e.bytes))").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    if !manager.history.entries.isEmpty {
                        Button("Effacer l'historique", role: .destructive) { manager.history.clear() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Téléchargements")
            .toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $showAdd) { addSheet }
            .alert("Téléchargement", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                if duplicateURL != nil {
                    Button("Télécharger quand même") {
                        if let u = duplicateURL { _ = manager.enqueue(url: u, name: nil, destination: dest, force: true) }
                        duplicateURL = nil
                    }
                }
                Button("OK", role: .cancel) { duplicateURL = nil }
            } message: { Text(message ?? "") }
        }
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                GSection("Lien direct vers un fichier") {
                    TextField("https://…/fichier.mp3", text: $urlText)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Picker("Destination", selection: $dest) { ForEach(DownloadDestination.allCases) { Text($0.label).tag($0) } }
                }
                GSection {
                    Button(addingBusy ? "Vérification…" : "Ajouter") { Task { await add() } }.disabled(addingBusy || urlText.isEmpty)
                }
                GSection { Text("Liens directs vers des fichiers audio/vidéo, ou liens SoundCloud/Vimeo téléchargeables via l'API officielle (jeton dans Réglages > Services). Les autres plateformes protègent leurs contenus : lecture via le site officiel.").font(.footnote).foregroundColor(.secondary) }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Nouveau téléchargement")
            .toolbar { Button("Fermer") { showAdd = false } }
        }
    }

    private func add() async {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)) else { message = "Lien invalide."; return }
        if ServiceRouter.service(for: url) != nil {
            addingBusy = true
            let msg = await ServiceDownloader.start(url: url, downloads: manager)
            addingBusy = false
            message = msg
            if msg.hasPrefix("Ajouté") { showAdd = false; urlText = "" }
            return
        }
        switch SourceAdapters.resolve(url) {
        case .refused(let why):
            addingBusy = true
            let probed = await SourceResolver.probe(url)
            addingBusy = false
            if case .directMedia = probed {
                finish(manager.enqueue(url: url, name: nil, destination: dest), url)
            } else { message = why }
        case .download(let u, let name, let d):
            finish(manager.enqueue(url: u, name: name, destination: dest == .auto ? d : dest), u)
        }
    }

    private func finish(_ r: EnqueueResult, _ url: URL) {
        switch r {
        case .added: showAdd = false; urlText = ""
        case .duplicate(let m): duplicateURL = url; message = m; showAdd = false
        case .alreadyActive: message = "Ce fichier est déjà dans la file."
        }
    }
}
