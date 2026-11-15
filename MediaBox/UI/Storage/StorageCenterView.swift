import SwiftUI

struct StorageCenterView: View {
    @EnvironmentObject var memory: MemoryManager
    @EnvironmentObject var storage: StorageAnalyzer
    @EnvironmentObject var library: MediaLibrary
    @EnvironmentObject var browser: BrowserManager
    @EnvironmentObject var downloads: DownloadManager
    @State private var snapshot: ResourceSnapshot?
    @State private var cacheSize: Int64 = 0
    @State private var confirmDelete: MediaItem?
    @State private var confirmClean = false

    var body: some View {
        List {
            Section("Mémoire de MediaBox") {
                row("Utilisée", Format.mb(memory.currentBytes))
                row("Pic enregistré", Format.mb(memory.peakBytes))
                row("Objectif de conception", "100 Mo")
                ProgressView(value: min(1, Double(memory.currentBytes) / Double(MemoryManager.defaultBudget)))
                if let s = snapshot {
                    row("CPU (instantané)", String(format: "%.0f %%", s.cpu))
                    row("Mémoire encore disponible (iOS)", Format.mb(s.available))
                    row("État thermique", ThermalMonitor.label(s.thermal))
                    row("Mode économie d'énergie", s.lowPower ? "Oui" : "Non")
                }
                if !memory.lastShedReport.isEmpty { Text(memory.lastShedReport).font(.caption).foregroundColor(.secondary) }
                Button("Mesurer maintenant") { snapshot = ResourceMonitor.shared.capture() }
                Button("Réinitialiser le pic") { memory.resetPeak() }
                Button("Libérer les ressources de MediaBox") { memory.shed(upTo: .freeInactiveModules, reason: "manuel", stopWhenUnderBudget: false); refreshCache() }
                Text("Libère uniquement les caches et modules de MediaBox ; cela ne vide pas la RAM d'iOS.").font(.caption).foregroundColor(.secondary)
            }
            Section("Caches et miniatures") {
                row("Miniatures sur disque", Format.bytes(cacheSize))
                Button("Vider les miniatures") { CacheManager.shared.purgeAll(); refreshCache() }
            }
            Section("Stockage") {
                row("Espace libre sur l'iPhone", Format.bytes(storage.report.freeSpace))
                row("Musique (dossier MediaBox)", Format.bytes(storage.report.musicBytes))
                row("Vidéos (dossier MediaBox)", Format.bytes(storage.report.videosBytes))
                row("Téléchargements", Format.bytes(storage.report.downloadsBytes))
                row("Caches", Format.bytes(storage.report.cacheBytes))
                row("Base de données", Format.bytes(storage.report.supportBytes))
                Button(storage.busy ? "Analyse…" : "Analyser") { Task { await storage.analyze(); refreshCache() } }.disabled(storage.busy)
            }
            Section("Plus gros fichiers") {
                if storage.largeFiles.isEmpty { Text("Lance une analyse.").foregroundColor(.secondary) }
                ForEach(storage.largeFiles) { it in
                    HStack { VStack(alignment: .leading) { Text(it.title).lineLimit(1); Text(it.kind == .video ? "Vidéo" : it.displayArtist).font(.caption).foregroundColor(.secondary) }
                        Spacer(); Text(Format.bytes(it.fileSize)).foregroundColor(.secondary) }
                        .swipeActions { Button(role: .destructive) { confirmDelete = it } label: { Label("Supprimer", systemImage: "trash") } }
                }
            }
            Section("Doublons") {
                Button(storage.busy ? "Recherche…" : "Rechercher les doublons") { Task { await storage.findDuplicates() } }.disabled(storage.busy)
                ForEach(Array(storage.duplicateGroups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading) {
                        Text(group.first?.title ?? "").font(.subheadline.weight(.semibold))
                        ForEach(group) { it in
                            HStack { Text(it.locator.path).font(.caption).lineLimit(1); Spacer()
                                Button(role: .destructive) { confirmDelete = it } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
                        }
                    }
                }
                Text("Comparaison par taille, durée et empreinte partielle (début + fin du fichier), uniquement à la demande.").font(.caption).foregroundColor(.secondary)
            }
            Section("Anciens téléchargements (> 30 jours)") {
                ForEach(storage.oldDownloads) { e in
                    HStack { Text(e.filename).lineLimit(1); Spacer(); Text(Format.bytes(e.bytes)).foregroundColor(.secondary) }
                }
                if storage.oldDownloads.isEmpty { Text("Aucun.").foregroundColor(.secondary) }
            }
            Section("Historique") {
                Button("Effacer l'historique du navigateur", role: .destructive) { confirmClean = true }
                Button("Effacer l'historique des téléchargements", role: .destructive) { downloads.history.clear() }
            }
        }
        .navigationTitle("Mémoire et stockage")
        .onAppear { snapshot = ResourceMonitor.shared.capture(); refreshCache(); Task { await storage.analyze() } }
        .confirmationDialog("Supprimer ce fichier ?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
            if let it = confirmDelete {
                if library.isManaged(it) {
                    Button("Supprimer le fichier de l'iPhone", role: .destructive) { library.deleteFiles(ids: [it.id]); Task { await storage.analyze() } }
                }
                Button("Retirer de la bibliothèque seulement") { library.remove(ids: [it.id]); Task { await storage.analyze() } }
            }
        } message: { Text("Les fichiers situés hors du dossier MediaBox ne sont jamais supprimés par l'app.") }
        .confirmationDialog("Effacer l'historique du navigateur ?", isPresented: $confirmClean, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) { browser.history.clear() }
        }
    }

    private func row(_ l: String, _ v: String) -> some View { HStack { Text(l); Spacer(); Text(v).foregroundColor(.secondary) } }
    private func refreshCache() { cacheSize = CacheManager.shared.diskSize() }
}
