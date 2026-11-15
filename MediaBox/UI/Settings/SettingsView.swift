import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var eco: EcoCore
    @EnvironmentObject var library: MediaLibrary
    @EnvironmentObject var sleepTimer: SleepTimer

    var body: some View {
        NavigationStack {
            Form {
                GSection("EcoCore") {
                    HStack { Text("Profil actif"); Spacer(); Text(eco.profile.label).foregroundColor(.secondary) }
                    Text(eco.reason).font(.footnote).foregroundColor(.secondary)
                    Picker("Mode", selection: Binding(get: { eco.manualProfile }, set: { eco.manualProfile = $0 })) {
                        Text("Automatique").tag(EcoProfile?.none)
                        ForEach(EcoProfile.allCases) { Text($0.label).tag(EcoProfile?.some($0)) }
                    }
                    Text("EcoCore réduit le travail de MediaBox ; c'est iOS qui gère le matériel (mode économie d'énergie, température).")
                        .font(.footnote).foregroundColor(.secondary)
                }
                GSection("Affichage") {
                    Picker("Thème", selection: $settings.appearance) { ForEach(Appearance.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                    Toggle("Lumière (halos de fond)", isOn: $settings.glow)
                    Toggle("Verre translucide (flou)", isOn: $settings.transparency)
                    Toggle("Animations", isOn: $settings.animations)
                    Toggle("Retour haptique", isOn: $settings.haptics)
                }
                GSection("Lecture") {
                    Stepper("Fondu entre morceaux : \(Int(settings.fadeSeconds)) s", value: $settings.fadeSeconds, in: 0...10)
                    Toggle("Reprendre la dernière session au lancement", isOn: $settings.restoreSession)
                    Toggle("Reprise après interruption", isOn: $settings.autoResume)
                }
                GSection("Téléchargements") {
                    Stepper("Simultanés : \(settings.maxDownloads)", value: $settings.maxDownloads, in: 1...3)
                    Toggle("Wi-Fi uniquement (au prochain lancement)", isOn: $settings.wifiOnlyDownloads)
                }
                GSection("Bibliothèque") {
                    Button("Réindexer maintenant") { library.scanAll() }
                    ForEach(library.roots.filter { $0.kind == .folder }) { Label($0.name, systemImage: "folder") }
                    Text("Dossier visible dans Fichiers : Sur mon iPhone > MediaBox (Musique, Vidéos, Téléchargements).").font(.footnote).foregroundColor(.secondary)
                }
                GSection("Services") {
                    ServiceTokenRow(service: .soundcloud)
                    ServiceTokenRow(service: .vimeo)
                    Text("Jetons personnels pour l'API officielle (SoundCloud, Vimeo). Stockés dans le Trousseau. Les autres services (YouTube, Spotify, TikTok, Twitch, Dailymotion) sont en lecture officielle uniquement.").font(.footnote).foregroundColor(.secondary)
                }
                GSection("Outils") {
                    NavigationLink { StorageCenterView() } label: { Label("Centre mémoire et stockage", systemImage: "memorychip") }
                    NavigationLink { BenchmarkView() } label: { Label("Benchmark", systemImage: "speedometer") }
                }
                GSection("À propos") {
                    Text("MediaBox 0.2.0 (développement)")
                    Text("Limites iOS : pas de lecture MKV/AVI/OGG/OPUS native ; sous-titres externes .srt non gérés ; téléchargements YouTube non pris en charge.").font(.footnote).foregroundColor(.secondary)
                }
            }.navigationTitle("Réglages")
        }
    }
}


struct ServiceTokenRow: View {
    let service: MediaService
    @State private var text = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(service.name).font(.subheadline.weight(.semibold))
                Spacer()
                if saved { Label("Jeton enregistré", systemImage: "checkmark.seal.fill").font(.caption).foregroundColor(.green) }
            }
            SecureField("Jeton d'accès \(service.name)", text: $text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            HStack {
                Button("Enregistrer") { ServiceCredentials.setToken(text, for: service); saved = !text.isEmpty; text = "" }.disabled(text.isEmpty)
                if saved { Button("Supprimer", role: .destructive) { ServiceCredentials.setToken(nil, for: service); saved = false } }
            }.font(.footnote).buttonStyle(.borderless)
        }
        .onAppear { saved = ServiceCredentials.token(for: service) != nil }
    }
}
