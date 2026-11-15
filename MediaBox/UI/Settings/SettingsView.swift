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
                Section("Apparence") {
                    Picker("Thème", selection: $settings.appearanceMode) {
                        Text("Automatique · iOS").tag("system")
                        Text("Clair élégant").tag("light")
                        Text("Sombre lumineux").tag("dark")
                    }
                    Toggle("Liquid Glass / transparence", isOn: $settings.transparency)
                    Toggle("Animations fluides", isOn: $settings.animations)
                    Toggle("Retour haptique", isOn: $settings.haptics)
                    Text("Le thème automatique suit l'apparence de l'iPhone. Les matériaux translucides sont réduits par EcoCore lorsque les ressources sont limitées.").font(.footnote).foregroundColor(.secondary)
                }
                Section("Services") {
                    ForEach(MediaService.all) { service in
                        HStack(spacing: 10) {
                            Image(systemName: service.symbol).frame(width: 24).foregroundColor(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.name)
                                Text(service.downloadNote).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }.padding(.vertical, 3)
                    }
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
                    Text("MediaBox 0.2.0 (refonte interface)")
                    Text("Les plateformes sont ouvertes via leurs sites officiels. Les téléchargements de contenus protégés ne sont pas pris en charge ; seuls les fichiers et exports autorisés peuvent être importés.").font(.footnote).foregroundColor(.secondary)
                }
            }.navigationTitle("Réglages")
        }
    }
}
