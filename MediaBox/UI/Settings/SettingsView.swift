import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var eco: EcoCore
    @EnvironmentObject var library: MediaLibrary
    @EnvironmentObject var sleepTimer: SleepTimer

    var body: some View {
        NavigationStack {
            Form {
                Section("EcoCore") {
                    HStack { Text("Profil actif"); Spacer(); Text(eco.profile.label).foregroundColor(.secondary) }
                    Text(eco.reason).font(.footnote).foregroundColor(.secondary)
                    Picker("Mode", selection: Binding(get: { eco.manualProfile }, set: { eco.manualProfile = $0 })) {
                        Text("Automatique").tag(EcoProfile?.none)
                        ForEach(EcoProfile.allCases) { Text($0.label).tag(EcoProfile?.some($0)) }
                    }
                    Text("EcoCore réduit le travail de MediaBox ; c'est iOS qui gère le matériel (mode économie d'énergie, température).")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("Affichage") {
                    Toggle("Effets de transparence", isOn: $settings.transparency)
                    Toggle("Animations", isOn: $settings.animations)
                    Toggle("Retour haptique", isOn: $settings.haptics)
                }
                Section("Lecture") {
                    Stepper("Fondu entre morceaux : \(Int(settings.fadeSeconds)) s", value: $settings.fadeSeconds, in: 0...10)
                    Toggle("Reprendre la dernière session au lancement", isOn: $settings.restoreSession)
                    Toggle("Reprise après interruption", isOn: $settings.autoResume)
                }
                Section("Téléchargements") {
                    Stepper("Simultanés : \(settings.maxDownloads)", value: $settings.maxDownloads, in: 1...3)
                    Toggle("Wi-Fi uniquement (au prochain lancement)", isOn: $settings.wifiOnlyDownloads)
                }
                Section("Bibliothèque") {
                    Button("Réindexer maintenant") { library.scanAll() }
                    ForEach(library.roots.filter { $0.kind == .folder }) { Label($0.name, systemImage: "folder") }
                    Text("Dossier visible dans Fichiers : Sur mon iPhone > MediaBox (Musique, Vidéos, Téléchargements).").font(.footnote).foregroundColor(.secondary)
                }
                Section("Outils") {
                    NavigationLink { StorageCenterView() } label: { Label("Centre mémoire et stockage", systemImage: "memorychip") }
                    NavigationLink { BenchmarkView() } label: { Label("Benchmark", systemImage: "speedometer") }
                }
                Section("À propos") {
                    Text("MediaBox 0.1.0 (développement)")
                    Text("Limites iOS : pas de lecture MKV/AVI/OGG/OPUS native ; sous-titres externes .srt non gérés ; téléchargements YouTube non pris en charge.").font(.footnote).foregroundColor(.secondary)
                }
            }.navigationTitle("Réglages")
        }
    }
}
